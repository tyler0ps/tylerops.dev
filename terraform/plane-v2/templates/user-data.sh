#!/bin/bash
set -e

# =============================================================================
# Plane-v2 EC2 Bootstrap Script (Stateless Compute)
# - Uses external PostgreSQL, Redis, RabbitMQ
# - Uses AWS S3 instead of MinIO
# - Uses built-in Caddy (plane-proxy) for HTTPS
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Plane-v2 setup ==="

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

# =============================================================================
# Mount EBS Data Volume (for Caddy certs persistence)
# =============================================================================
echo "=== Setting up data volume ==="

DATA_MOUNT="/opt/plane-data"

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

# Create data directories for built-in Caddy (plane-proxy)
mkdir -p $DATA_MOUNT/caddy/{data,config}

# =============================================================================
# Install Plane Community Edition
# Ref: https://developers.plane.so/self-hosting/methods/docker-compose
# =============================================================================
echo "=== Installing Plane Community Edition ==="

PLANE_DIR="/opt/plane-selfhost"
mkdir -p $PLANE_DIR
cd $PLANE_DIR

# Download and run official Plane setup script
curl -fsSL -o setup.sh https://github.com/makeplane/plane/releases/latest/download/setup.sh
chmod +x setup.sh

# Run setup script to download files (option 1 = install)

mkdir -p plane-app
cd plane-app

# Configure plane.env with external services
cat > plane.env <<EOF
# Database Settings - External PostgreSQL
PGHOST=${db_host}
PGDATABASE=${db_name}
POSTGRES_USER=${db_user}
POSTGRES_PASSWORD=${db_password}
POSTGRES_DB=${db_name}
POSTGRES_PORT=5432
DATABASE_URL=postgresql://${db_user}:${db_password}@${db_host}:5432/${db_name}

# Redis Settings - External Redis
REDIS_HOST=${redis_host}
REDIS_PORT=6379
REDIS_URL=redis://${redis_host}:6379/

# RabbitMQ Settings - External RabbitMQ
RABBITMQ_HOST=${mq_host}
RABBITMQ_PORT=5672
RABBITMQ_DEFAULT_USER=${mq_user}
RABBITMQ_DEFAULT_PASS=${mq_password}
RABBITMQ_VHOST=${mq_vhost}
AMQP_URL=amqp://${mq_user}:${mq_password}@${mq_host}:5672/${mq_vhost}

# Application URLs
WEB_URL=https://${domain}
CORS_ALLOWED_ORIGINS=https://${domain}

# SSL Settings - Built-in Caddy (plane-proxy) handles HTTPS
SITE_ADDRESS=${domain}
LISTEN_HTTP_PORT=80
LISTEN_HTTPS_PORT=443
TRUSTED_PROXIES=0.0.0.0/0
CERT_EMAIL="email me@tylerops.dev"
CERT_ACME_CA=https://acme-staging-v02.api.letsencrypt.org/directory

# Secret key
SECRET_KEY=$(openssl rand -hex 24)

# AWS S3 Settings (instead of MinIO)
USE_MINIO=0
AWS_REGION=${s3_region}
AWS_S3_BUCKET_NAME=${s3_bucket}
FILE_SIZE_LIMIT=5242880

# Feature Flags
ENABLE_SIGNUP=1
ENABLE_EMAIL_PASSWORD=1
ENABLE_MAGIC_LINK_LOGIN=0
GUNICORN_WORKERS=1

# API Rate Limit
API_KEY_RATE_LIMIT=60/minute
EOF

cd ..
echo "1" | ./setup.sh
echo "2" | ./setup.sh

echo "=== Plane-v2 bootstrap complete ==="
echo ""
echo "plane.env has been configured at: /opt/plane-selfhost/plane-app/plane.env"
echo ""
echo "External services configured:"
echo "  PostgreSQL: ${db_host}:5432"
echo "  Redis: ${redis_host}:6379"
echo "  RabbitMQ: ${mq_host}:5672"
echo "  S3: ${s3_bucket}"
echo ""
echo "Next steps (SSH into instance and run manually):"
echo "  1. cd /opt/plane-selfhost/plane-app"
echo "  2. Review/modify plane.env and docker-compose.yaml as needed"
echo "  3. docker compose up -d"
echo ""
echo "Caddy certs will be stored at: /opt/plane-data/caddy/"
