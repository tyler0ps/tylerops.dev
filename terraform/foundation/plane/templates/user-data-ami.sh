#!/bin/bash
set -e

# =============================================================================
# Plane EC2 Bootstrap Script (AMI-based)
# Docker, Compose, and Plane files are already in the AMI.
# This script: self-attaches EBS, mounts volume, registers DNS, starts Plane.
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Plane (AMI-based boot, ASG mode) ==="
echo "Timestamp: $(date)"

# =============================================================================
# Ensure SSM Agent + Docker are running
# =============================================================================
echo "=== Ensuring SSM Agent is running ==="
systemctl start amazon-ssm-agent || true

# =============================================================================
# Swap (protects SSM agent + system from OOM during Plane/Postgres startup)
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
# Get Instance Metadata (IMDSv2)
# =============================================================================
echo "=== Getting instance metadata ==="

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"

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

DATA_MOUNT="/opt/plane-data"

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

  # Create filesystem if not exists (first boot after EBS creation)
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

  # Create data directories if they don't exist
  mkdir -p $DATA_MOUNT/{postgres,minio,redis,caddy/data,caddy/config}
  chown -R 999:999 $DATA_MOUNT/postgres
  chown -R 999:999 $DATA_MOUNT/redis
  chown -R 1000:1000 $DATA_MOUNT/minio
fi

# =============================================================================
# Register internal DNS: plane.tylerops.internal → private IP
# =============================================================================
echo "=== Registering internal DNS ==="

aws route53 change-resource-record-sets \
  --hosted-zone-id "${internal_zone_id}" \
  --change-batch "{
    \"Changes\": [
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"plane.tylerops.internal\",
          \"Type\": \"A\",
          \"TTL\": 30,
          \"ResourceRecords\": [{\"Value\": \"$PRIVATE_IP\"}]
        }
      }
    ]
  }" \
  --region ${aws_region}

echo "DNS registered: plane.tylerops.internal → $PRIVATE_IP"

# =============================================================================
# Write plane.env to EBS on first boot only
# (persisted on EBS so SECRET_KEY and other values survive spot replacements)
# =============================================================================
PLANE_ENV="$DATA_MOUNT/plane.env"

if [ ! -f "$PLANE_ENV" ]; then
  echo "=== Writing plane.env (first boot) ==="
  cat > $PLANE_ENV << EOF
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
CERT_ACME_CA=https://acme-v02.api.letsencrypt.org/directory

# HTTP only — SSL terminated at external Caddy reverse proxy
SITE_ADDRESS=:80
LISTEN_HTTP_PORT=80
TRUSTED_PROXIES=0.0.0.0/0

# Secret key (generated once, persisted on EBS)
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
  echo "plane.env written"
else
  echo "plane.env already exists on EBS, skipping"
fi

# =============================================================================
# Symlink plane.env so Plane's docker compose picks it up
# =============================================================================
echo "=== Symlinking plane.env ==="
ln -sf $PLANE_ENV /opt/plane-selfhost/plane-app/plane.env

# =============================================================================
# Start Plane services (install already done in AMI)
# =============================================================================
echo "=== Starting Plane services ==="

PLANE_DIR="/opt/plane-selfhost"

if [ -d "$PLANE_DIR" ]; then
  cd $PLANE_DIR

  # Stop any containers docker daemon auto-started before EBS was mounted
  cd plane-app
  docker compose down 2>/dev/null || true
  cd ..

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
