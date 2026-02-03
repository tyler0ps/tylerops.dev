#!/bin/bash
set -e

# =============================================================================
# Plane EC2 Bootstrap Script (AMI-based - simplified)
# Docker, Compose, and Plane are already installed in the AMI
# This script only mounts EBS and starts services
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Plane (AMI-based boot) ==="
echo "Timestamp: $(date)"

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
# Mount EBS Data Volume (contains PostgreSQL, MinIO, Redis data)
# =============================================================================
echo "=== Mounting data volume ==="

DATA_MOUNT="/opt/plane-data"

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
  mount $DATA_DEVICE $DATA_MOUNT

  # Add to fstab for persistence across reboots
  if ! grep -q "$DATA_MOUNT" /etc/fstab; then
    echo "$DATA_DEVICE $DATA_MOUNT xfs defaults,nofail 0 2" >> /etc/fstab
  fi

  # Create data directories if they don't exist
  mkdir -p $DATA_MOUNT/{postgres,minio,redis,caddy/data,caddy/config}
  chown -R 999:999 $DATA_MOUNT/postgres
  chown -R 999:999 $DATA_MOUNT/redis
  chown -R 1000:1000 $DATA_MOUNT/minio
fi

# =============================================================================
# Start Plane services
# =============================================================================
echo "=== Starting Plane services ==="

PLANE_DIR="/opt/plane-selfhost"

if [ -d "$PLANE_DIR" ]; then
  cd $PLANE_DIR

  # Start services using setup.sh (option 4 = start)
  echo "4" | ./setup.sh

  echo "=== Waiting for services to start ==="
  sleep 30

  cd plane-app
  docker compose ps
else
  echo "ERROR: Plane directory not found at $PLANE_DIR"
  echo "This AMI may not have Plane pre-installed"
  exit 1
fi

echo "=== Plane startup complete ==="
echo "Access at: https://${domain}"
