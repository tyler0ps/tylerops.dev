#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Plane from AMI ==="

# =============================================================================
# Mount EBS Data Volume
# =============================================================================
echo "=== Mounting data volume ==="

DATA_MOUNT="/opt/plane-data"

for i in {1..60}; do
  if [ -e /dev/nvme1n1 ]; then
    DATA_DEVICE="/dev/nvme1n1"
    break
  elif [ -e /dev/xvdf ]; then
    DATA_DEVICE="/dev/xvdf"
    break
  fi
  echo "Waiting for data volume... ($i/60)"
  sleep 5
done

if [ -z "$DATA_DEVICE" ]; then
  echo "ERROR: Data volume not found"
  exit 1
fi

# Create filesystem if new volume
if ! blkid $DATA_DEVICE; then
  echo "Creating filesystem..."
  mkfs.xfs $DATA_DEVICE
fi

mkdir -p $DATA_MOUNT

# Mount only if not already mounted
if ! mountpoint -q $DATA_MOUNT; then
  mount $DATA_DEVICE $DATA_MOUNT
else
  echo "$DATA_MOUNT already mounted"
fi

# Add to fstab
grep -q "$DATA_MOUNT" /etc/fstab || echo "$DATA_DEVICE $DATA_MOUNT xfs defaults,nofail 0 2" >> /etc/fstab

# =============================================================================
# Test Connections
# =============================================================================
echo "=== Testing connections ==="

timeout 3 bash -c "echo >/dev/tcp/${db_host}/5432" && echo "✓ PostgreSQL" || echo "✗ PostgreSQL"
timeout 3 bash -c "echo >/dev/tcp/${redis_host}/6379" && echo "✓ Redis" || echo "✗ Redis"
timeout 3 bash -c "echo >/dev/tcp/${mq_host}/5672" && echo "✓ RabbitMQ" || echo "✗ RabbitMQ"

# =============================================================================
# Update plane.env (override changed values only)
# =============================================================================
echo "=== Updating plane.env ==="

PLANE_ENV="/opt/plane/plane.env"

# Database
sed -i "s|^PGHOST=.*|PGHOST=${db_host}|" $PLANE_ENV
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${db_password}|" $PLANE_ENV
sed -i "s|^DATABASE_URL=.*|DATABASE_URL=postgresql://${db_user}:${db_password}@${db_host}:5432/${db_name}|" $PLANE_ENV

# Redis
sed -i "s|^REDIS_HOST=.*|REDIS_HOST=${redis_host}|" $PLANE_ENV
sed -i "s|^REDIS_URL=.*|REDIS_URL=redis://${redis_host}:6379/|" $PLANE_ENV

# RabbitMQ
sed -i "s|^RABBITMQ_HOST=.*|RABBITMQ_HOST=${mq_host}|" $PLANE_ENV
sed -i "s|^RABBITMQ_DEFAULT_PASS=.*|RABBITMQ_DEFAULT_PASS=${mq_password}|" $PLANE_ENV
sed -i "s|^AMQP_URL=.*|AMQP_URL=amqp://${mq_user}:${mq_password}@${mq_host}:5672/${mq_vhost}|" $PLANE_ENV

# S3
sed -i "s|^AWS_ACCESS_KEY_ID=.*|AWS_ACCESS_KEY_ID=${s3_access_key}|" $PLANE_ENV
sed -i "s|^AWS_SECRET_ACCESS_KEY=.*|AWS_SECRET_ACCESS_KEY=${s3_secret_key}|" $PLANE_ENV

# Domain
sed -i "s|^DOMAIN_NAME=.*|DOMAIN_NAME=${domain}|" $PLANE_ENV
sed -i "s|^SITE_ADDRESS=.*|SITE_ADDRESS=${domain}|" $PLANE_ENV
sed -i "s|^WEB_URL=.*|WEB_URL=https://${domain}|" $PLANE_ENV
sed -i "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=http://${domain},https://${domain}|" $PLANE_ENV

echo "Updated values in $PLANE_ENV"

# =============================================================================
# Start Plane
# =============================================================================
echo "=== Starting Plane ==="

prime-cli restart

echo "=== Plane startup complete ==="
echo "URL: https://${domain}"
