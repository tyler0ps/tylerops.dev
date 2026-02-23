#!/bin/bash
set -e

# =============================================================================
# Plane EE AMI Baker - Bootstrap Script
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Plane EE AMI baker setup ==="

# =============================================================================
# Install and Enable SSM Agent
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

# =============================================================================
# Mount EBS Data Volume
# =============================================================================
echo "=== Setting up data volume ==="

DATA_MOUNT="/opt/plane"

# Detect EBS volume - handles both Nitro (NVMe) and non-Nitro instances
echo "Waiting for data volume..."
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

# Create filesystem if not exists
if ! blkid $DATA_DEVICE; then
  echo "Creating filesystem on data volume..."
  mkfs.xfs $DATA_DEVICE
fi

# Mount volume
mkdir -p $DATA_MOUNT
mount $DATA_DEVICE $DATA_MOUNT

# Add to fstab for persistence across reboots
if ! grep -q "$DATA_MOUNT" /etc/fstab; then
  echo "$DATA_DEVICE $DATA_MOUNT xfs defaults,nofail 0 2" >> /etc/fstab
fi

echo "=== Setup complete ==="
echo "Docker, Compose, Buildx, SSM Agent installed"
echo "EBS mounted at $DATA_MOUNT"
echo "Ready for Plane EE installation"
