#!/bin/bash
set -e

# =============================================================================
# Authentik EC2 Bootstrap Script
# This script: self-attaches EBS + EIP, mounts data volume
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# =============================================================================
# Install and Enable SSM Agent (for Session Manager access)
# =============================================================================
echo "=== Installing SSM Agent ==="
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent


# Update system
dnf update -y

# =============================================================================
# Install Docker
# =============================================================================
echo "=== Installing Docker ==="
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# =============================================================================
# Install Docker Buildx
# =============================================================================
echo "=== Installing Docker Buildx ==="
BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
mkdir -p /usr/local/lib/docker/cli-plugins
curl -L "https://github.com/docker/buildx/releases/download/v$BUILDX_VERSION/buildx-v$BUILDX_VERSION.linux-arm64" \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# =============================================================================
# Install Docker Compose
# =============================================================================
echo "=== Installing Docker Compose ==="
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
curl -L "https://github.com/docker/compose/releases/download/v$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

echo "=== Starting Authentik bootstrap ==="
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
# Associate Elastic IP
# =============================================================================
echo "=== Associating Elastic IP ==="

EIP_ALLOC_ID="${eip_alloc_id}"

CURRENT_ASSOC=$(aws ec2 describe-addresses --allocation-ids $EIP_ALLOC_ID --region ${aws_region} --query 'Addresses[0].AssociationId' --output text 2>/dev/null || echo "None")

if [ "$CURRENT_ASSOC" != "None" ] && [ -n "$CURRENT_ASSOC" ]; then
  echo "Disassociating EIP from previous instance..."
  aws ec2 disassociate-address --association-id $CURRENT_ASSOC --region ${aws_region} || true
  sleep 2
fi

aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $EIP_ALLOC_ID --region ${aws_region}
echo "EIP associated successfully"

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

  # Create filesystem if not exists (first boot)
  if ! blkid $DATA_DEVICE; then
    echo "Creating filesystem on data volume..."
    mkfs.xfs $DATA_DEVICE
  fi

  mkdir -p $DATA_MOUNT
  mount $DATA_DEVICE $DATA_MOUNT

  # Persist across reboots
  if ! grep -q "$DATA_MOUNT" /etc/fstab; then
    echo "$DATA_DEVICE $DATA_MOUNT xfs defaults,nofail 0 2" >> /etc/fstab
  fi

  # Create data directories for Authentik + Caddy cert storage
  mkdir -p $DATA_MOUNT/{postgres,redis,media,certs,backups,caddy/data,caddy/config}
fi

# =============================================================================
# Install Caddy (reverse proxy + automatic SSL via Let's Encrypt)
# Certs stored on persistent EBS volume — survives spot replacements
# =============================================================================
echo "=== Installing Caddy ==="

CADDY_VER=$(curl -s https://api.github.com/repos/caddyserver/caddy/releases/latest \
  | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
curl -L "https://github.com/caddyserver/caddy/releases/download/v$${CADDY_VER}/caddy_$${CADDY_VER}_linux_arm64.tar.gz" \
  | tar xz caddy
mv caddy /usr/local/bin/caddy

# caddy user — home on EBS so certs survive instance replacement
useradd --system --home /opt/authentik-data/caddy --shell /usr/sbin/nologin caddy 2>/dev/null || true
chown -R caddy:caddy /opt/authentik-data/caddy

# Caddyfile — reverse proxy to Authentik HTTP port
mkdir -p /etc/caddy
cat > /etc/caddy/Caddyfile <<'CADDYEOF'
${domain} {
    reverse_proxy localhost:9000
}
CADDYEOF

# systemd service
cat > /etc/systemd/system/caddy.service <<'CADDY_SVC'
[Unit]
Description=Caddy
After=network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
Environment=XDG_DATA_HOME=/opt/authentik-data/caddy/data
Environment=XDG_CONFIG_HOME=/opt/authentik-data/caddy/config
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
CADDY_SVC

systemctl daemon-reload
systemctl enable caddy
systemctl start caddy

echo "=== Authentik bootstrap complete ==="
echo "Caddy started — SSL cert will be provisioned at: https://${domain}"
