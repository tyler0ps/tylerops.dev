#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Plane from AMI (ASG Mode) ==="

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
    # Wait for detach
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

# Attach volume if not attached
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

script -q -c "prime-cli restart" /dev/null

echo "=== Plane startup complete ==="
echo "URL: https://${domain}"
