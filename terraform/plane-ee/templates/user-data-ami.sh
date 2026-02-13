#!/bin/bash
set -e

# =============================================================================
# Plane EE Bootstrap Script (AMI-based)
# Docker, Compose, and Plane EE are already installed in the AMI
# This script: self-attaches EBS + EIP, mounts volume, starts services
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Plane EE (AMI-based boot, ASG mode) ==="
echo "Timestamp: $(date)"

# =============================================================================
# Get Instance Metadata (IMDSv2)
# =============================================================================
echo "=== Getting instance metadata ==="

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

echo "Instance ID: $INSTANCE_ID"
echo "Availability Zone: $AZ"

# =============================================================================
# Ensure SSM Agent is running
# =============================================================================
echo "=== Ensuring SSM Agent is running ==="
systemctl start amazon-ssm-agent || true

# =============================================================================
# Ensure Docker is running
# =============================================================================
echo "=== Ensuring Docker is running ==="
systemctl start docker
systemctl enable docker

# =============================================================================
# Associate Elastic IP
# =============================================================================
echo "=== Associating Elastic IP ==="

EIP_ALLOC_ID="${eip_alloc_id}"

# Check if EIP is already associated to another instance
CURRENT_ASSOC=$(aws ec2 describe-addresses --allocation-ids $EIP_ALLOC_ID --region ${aws_region} --query 'Addresses[0].AssociationId' --output text 2>/dev/null || echo "None")

if [ "$CURRENT_ASSOC" != "None" ] && [ -n "$CURRENT_ASSOC" ]; then
  echo "Disassociating EIP from previous instance..."
  aws ec2 disassociate-address --association-id $CURRENT_ASSOC --region ${aws_region} || true
  sleep 2
fi

echo "Associating EIP to this instance..."
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $EIP_ALLOC_ID --region ${aws_region}
echo "EIP associated successfully"

# =============================================================================
# Attach EBS Data Volume
# =============================================================================
echo "=== Attaching EBS volume ==="

EBS_VOLUME_ID="${ebs_volume_id}"

# Check current volume state
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

# Attach volume if not attached to this instance
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

DATA_MOUNT="/opt/plane"

# Skip if already mounted (e.g., on reboot)
if mountpoint -q $DATA_MOUNT; then
  echo "Data volume already mounted at $DATA_MOUNT"
else
  # Detect EBS volume - handles both Nitro (NVMe) and non-Nitro instances
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

  # Mount volume
  mkdir -p $DATA_MOUNT
  if mountpoint -q $DATA_MOUNT; then
    echo "Data volume already auto-mounted at $DATA_MOUNT"
  else
    mount $DATA_DEVICE $DATA_MOUNT
  fi

  # Add to fstab for persistence across reboots
  if ! grep -q "$DATA_MOUNT" /etc/fstab; then
    echo "$DATA_DEVICE $DATA_MOUNT xfs defaults,nofail 0 2" >> /etc/fstab
  fi
fi

# =============================================================================
# Start Plane EE services
# =============================================================================
echo "=== Starting Plane EE services ==="

if command -v prime-cli &> /dev/null; then
  script -qec "prime-cli restart" /dev/null

  echo "=== Waiting for services to start ==="
  sleep 30

  docker compose ps 2>/dev/null || docker ps
else
  echo "ERROR: prime-cli not found"
  echo "This AMI may not have Plane EE pre-installed"
  exit 1
fi

echo "=== Plane EE startup complete ==="
echo "Access at: https://${domain}"
