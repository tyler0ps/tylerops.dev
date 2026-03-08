#!/bin/bash
set -e

# =============================================================================
# Authentik EC2 Bootstrap Script (AMI-based)
# Docker, Compose, and Authentik config are already in the AMI.
# This script: mounts EBS data volume and starts Authentik.
# No EIP (private subnet behind reverse proxy). No Caddy.
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Authentik (AMI-based boot) ==="
echo "Timestamp: $(date)"

# =============================================================================
# Ensure SSM Agent + Docker are running
# =============================================================================
echo "=== Ensuring SSM Agent is running ==="
systemctl start amazon-ssm-agent || true

# =============================================================================
# Swap (protects SSM agent + system from OOM killer during Authentik spikes)
# =============================================================================
echo "=== Setting up swap ==="
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "Swap enabled"
else
  echo "Swap already active"
fi

echo "=== Ensuring Docker is running ==="
systemctl start docker
systemctl enable docker

# =============================================================================
# Get Instance Metadata (IMDSv2) — needed for EBS attach
# =============================================================================
echo "=== Getting instance metadata ==="

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Instance ID: $INSTANCE_ID"
echo "Availability Zone: $AZ"
echo "Private IP: $PRIVATE_IP"

# =============================================================================
# Register Internal DNS
# TTL=30 ensures fast failover on spot replacement.
# =============================================================================
echo "=== Registering internal DNS ==="

aws route53 change-resource-record-sets \
  --hosted-zone-id "${internal_zone_id}" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"authentik.tylerops.internal\",
        \"Type\": \"A\",
        \"TTL\": 30,
        \"ResourceRecords\": [{\"Value\": \"$PRIVATE_IP\"}]
      }
    }]
  }" \
  --region ${aws_region}

echo "Internal DNS registered: authentik.tylerops.internal -> $PRIVATE_IP"

# =============================================================================
# Attach EBS Data Volume
# =============================================================================
echo "=== Attaching EBS volume ==="

EBS_VOLUME_ID="${ebs_volume_id}"

VOLUME_STATE=$(aws ec2 describe-volumes --volume-ids $EBS_VOLUME_ID --region ${aws_region} --query 'Volumes[0].State' --output text)
echo "Volume state: $VOLUME_STATE"

if [ "$VOLUME_STATE" == "in-use" ]; then
  ATTACHED_INSTANCE=$(aws ec2 describe-volumes --volume-ids $EBS_VOLUME_ID --region ${aws_region} --query 'Volumes[0].Attachments[0].InstanceId' --output text)
  if [ "$ATTACHED_INSTANCE" != "$INSTANCE_ID" ]; then
    echo "Detaching volume from previous instance $ATTACHED_INSTANCE..."
    aws ec2 detach-volume --volume-id $EBS_VOLUME_ID --region ${aws_region} --force || true
    for i in {1..30}; do
      STATE=$(aws ec2 describe-volumes --volume-ids $EBS_VOLUME_ID --region ${aws_region} --query 'Volumes[0].State' --output text)
      if [ "$STATE" == "available" ]; then
        echo "Volume detached"
        break
      fi
      echo "Waiting for volume to detach... ($i/30)"
      sleep 5
    done
  else
    echo "Volume already attached to this instance"
  fi
fi

VOLUME_STATE=$(aws ec2 describe-volumes --volume-ids $EBS_VOLUME_ID --region ${aws_region} --query 'Volumes[0].State' --output text)
if [ "$VOLUME_STATE" == "available" ]; then
  echo "Attaching EBS volume..."
  aws ec2 attach-volume --volume-id $EBS_VOLUME_ID --instance-id $INSTANCE_ID --device /dev/xvdf --region ${aws_region}
  echo "Volume attach initiated"
fi

# =============================================================================
# Mount EBS Data Volume
# =============================================================================
echo "=== Mounting data volume ==="

DATA_MOUNT="/opt/authentik-data"

if mountpoint -q $DATA_MOUNT; then
  echo "Data volume already mounted at $DATA_MOUNT"
else
  echo "Waiting for data volume..."
  DATA_DEVICE=""
  for i in {1..60}; do
    if [ -e /dev/nvme1n1 ]; then
      DATA_DEVICE="/dev/nvme1n1"
      break
    elif [ -e /dev/xvdf ]; then
      DATA_DEVICE="/dev/xvdf"
      break
    fi
    echo "Waiting for data volume to attach... ($i/60)"
    sleep 5
  done

  if [ -z "$DATA_DEVICE" ]; then
    echo "ERROR: Data volume not found after 5 minutes"
    exit 1
  fi
  echo "Found data volume at $DATA_DEVICE"

  # Create filesystem if not exists (first boot after AMI creation)
  if ! blkid $DATA_DEVICE; then
    echo "Creating filesystem on data volume..."
    mkfs.xfs $DATA_DEVICE
  fi

  mkdir -p $DATA_MOUNT
  if mountpoint -q $DATA_MOUNT; then
    echo "Data volume already auto-mounted at $DATA_MOUNT"
  else
    mount $DATA_DEVICE $DATA_MOUNT
  fi

  # Persist across reboots
  if ! grep -q "$DATA_MOUNT" /etc/fstab; then
    echo "$DATA_DEVICE $DATA_MOUNT xfs defaults,nofail 0 2" >> /etc/fstab
  fi

  # Create data directories
  mkdir -p $DATA_MOUNT/{postgres,redis,media,certs,backups,custom-templates,data}
fi

# =============================================================================
# Start Authentik
# compose.yml is baked into AMI at /opt/authentik/compose.yml
# .env with secrets lives on EBS at /opt/authentik-data/.env
# Symlink .env so docker compose variable substitution works
# =============================================================================
echo "=== Starting Authentik ==="

AUTHENTIK_DIR="/opt/authentik"

if [ -d "$AUTHENTIK_DIR" ]; then
  # Symlink .env from EBS — docker compose reads it for variable interpolation
  ln -sf /opt/authentik-data/.env $AUTHENTIK_DIR/.env

  cd $AUTHENTIK_DIR

  # Stop any containers docker daemon auto-started before EBS was mounted.
  # Without this, postgres would use an empty bind mount on root volume.
  docker compose down 2>/dev/null || true

  docker compose up -d
  echo "=== Waiting for services to start ==="
  sleep 30
  docker compose ps
else
  echo "ERROR: Authentik directory not found at $AUTHENTIK_DIR"
  echo "This AMI may not have Authentik pre-configured"
  exit 1
fi

echo "=== Authentik startup complete ==="
