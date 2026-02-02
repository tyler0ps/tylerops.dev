#!/bin/bash
set -e

# =============================================================================
# Plane EC2 Bootstrap Script (Simple Setup)
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Plane setup ==="

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
# Mount EBS Data Volume (30GB for PostgreSQL, MinIO, Redis)
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

# Create data directories with correct ownership
mkdir -p $DATA_MOUNT/{postgres,minio,redis,caddy/data,caddy/config}
chown -R 999:999 $DATA_MOUNT/postgres   # PostgreSQL UID
chown -R 999:999 $DATA_MOUNT/redis      # Redis UID
chown -R 1000:1000 $DATA_MOUNT/minio    # MinIO UID
# Caddy runs as root in the container, no chown needed

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
echo "1" | ./setup.sh

cd plane-app

# Configure plane.env with default settings
cat > plane.env <<EOF
# Database Settings
PGHOST=plane-db
PGDATABASE=plane
POSTGRES_USER=plane
POSTGRES_PASSWORD=plane
POSTGRES_DB=plane
POSTGRES_PORT=5432
PGDATA=/var/lib/postgresql/data
DATABASE_URL=postgresql://plane:plane@plane-db:5432/plane

# Redis Settings
REDIS_HOST=plane-redis
REDIS_PORT=6379
REDIS_URL=redis://plane-redis:6379/

# RabbitMQ Settings
RABBITMQ_HOST=plane-mq
RABBITMQ_PORT=5672
RABBITMQ_DEFAULT_USER=plane
RABBITMQ_DEFAULT_PASS=plane
RABBITMQ_VHOST=plane
AMQP_URL=amqp://plane:plane@plane-mq:5672/plane

# Application URLs
WEB_URL=https://${domain}
CORS_ALLOWED_ORIGINS=https://${domain}

# SSL Settings
CERT_EMAIL="email me@tylerops.dev"
CERT_ACME_CA=https://acme-v02.api.letsencrypt.org/directory
SITE_ADDRESS=${domain}
LISTEN_HTTP_PORT=80
LISTEN_HTTPS_PORT=443
TRUSTED_PROXIES=0.0.0.0/0

# Secret key
SECRET_KEY=$(openssl rand -hex 24)

# MinIO Settings
USE_MINIO=1
AWS_REGION=ap-southeast-1
AWS_ACCESS_KEY_ID=access-key
AWS_SECRET_ACCESS_KEY=secret-key
AWS_S3_ENDPOINT_URL=http://plane-minio:9000
AWS_S3_BUCKET_NAME=uploads
MINIO_ROOT_USER=access-key
MINIO_ROOT_PASSWORD=secret-key
MINIO_ENDPOINT_SSL=0
FILE_SIZE_LIMIT=5242880

# Feature Flags
ENABLE_SIGNUP=1
ENABLE_EMAIL_PASSWORD=1
ENABLE_MAGIC_LINK_LOGIN=0
GUNICORN_WORKERS=1

# API Rate Limit
API_KEY_RATE_LIMIT=60/minute
EOF

# Modify docker-compose.yaml to use EBS bind mounts instead of named volumes
sed -i 's|pgdata:/var/lib/postgresql/data|/opt/plane-data/postgres:/var/lib/postgresql/data|g' docker-compose.yaml
sed -i 's|redisdata:/data|/opt/plane-data/redis:/data|g' docker-compose.yaml
sed -i 's|uploads:/export|/opt/plane-data/minio:/export|g' docker-compose.yaml
# Caddy proxy volumes (certificates stored in proxy_data)
sed -i 's|proxy_data:/data|/opt/plane-data/caddy/data:/data|g' docker-compose.yaml
sed -i 's|proxy_config:/config|/opt/plane-data/caddy/config:/config|g' docker-compose.yaml

# Start Plane (option 2 = start)
echo "=== Starting Plane services ==="
cd /opt/plane-selfhost
echo "2" | ./setup.sh

echo "=== Waiting for services to start ==="
sleep 30

cd plane-app
docker compose ps

echo "=== Plane setup complete ==="
echo "Access at: https://${domain}"
