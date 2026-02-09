#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Data Instance Setup (PostgreSQL + Redis + RabbitMQ) ==="

# =============================================================================
# Install SSM Agent
# =============================================================================
echo "=== Installing SSM Agent ==="
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Update system
dnf update -y

# =============================================================================
# Mount EBS Data Volume
# =============================================================================
echo "=== Setting up data volume ==="

DATA_MOUNT="/data"

# Wait for EBS volume
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

# Add to fstab
if ! grep -q "$DATA_MOUNT" /etc/fstab; then
  echo "$DATA_DEVICE $DATA_MOUNT xfs defaults,nofail 0 2" >> /etc/fstab
fi

# Create data directories
mkdir -p $DATA_MOUNT/{postgres,redis,rabbitmq}

# =============================================================================
# Install PostgreSQL 15
# =============================================================================
echo "=== Installing PostgreSQL 15 ==="

dnf install -y postgresql15-server postgresql15

# Set ownership
chown -R postgres:postgres $DATA_MOUNT/postgres

# Initialize database if not already done
if [ ! -f "$DATA_MOUNT/postgres/PG_VERSION" ]; then
  echo "Initializing PostgreSQL database..."
  sudo -u postgres /usr/bin/initdb -D $DATA_MOUNT/postgres
fi

# Configure PostgreSQL
cat > $DATA_MOUNT/postgres/postgresql.conf <<EOF
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 768MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 7864kB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 1310kB
min_wal_size = 1GB
max_wal_size = 4GB
data_directory = '$DATA_MOUNT/postgres'
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_rotation_age = 1d
log_rotation_size = 100MB
EOF

# Configure authentication - allow VPC access
cat > $DATA_MOUNT/postgres/pg_hba.conf <<EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    all             all             ${vpc_cidr}             scram-sha-256
EOF

chown postgres:postgres $DATA_MOUNT/postgres/postgresql.conf
chown postgres:postgres $DATA_MOUNT/postgres/pg_hba.conf

# Create systemd override for custom data directory
mkdir -p /etc/systemd/system/postgresql.service.d
cat > /etc/systemd/system/postgresql.service.d/override.conf <<EOF
[Service]
Environment=PGDATA=$DATA_MOUNT/postgres
EOF

# Start PostgreSQL
systemctl daemon-reload
systemctl enable postgresql
systemctl start postgresql

# Wait for PostgreSQL to start
sleep 5

# Create database and user
echo "=== Creating PostgreSQL database and user ==="
sudo -u postgres psql <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
    CREATE USER ${db_user} WITH PASSWORD '${db_password}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
EOF

echo "PostgreSQL: ${db_name} on port 5432"

# =============================================================================
# Install Redis 7
# =============================================================================
echo "=== Installing Redis ==="

dnf install -y redis6

# Configure Redis
cat > /etc/redis6/redis6.conf <<EOF
bind 0.0.0.0
port 6379
daemonize no
supervised systemd
dir $DATA_MOUNT/redis
dbfilename dump.rdb
appendonly yes
appendfilename "appendonly.aof"
maxmemory 256mb
maxmemory-policy allkeys-lru
EOF

chown -R redis6:redis6 $DATA_MOUNT/redis

# Start Redis
systemctl enable redis6
systemctl start redis6

echo "Redis: port 6379"

# =============================================================================
# Install RabbitMQ via Docker (AL2023 doesn't have erlang in repos)
# =============================================================================
echo "=== Installing RabbitMQ via Docker ==="

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Create RabbitMQ data directory
mkdir -p $DATA_MOUNT/rabbitmq
chown -R 999:999 $DATA_MOUNT/rabbitmq

# Run RabbitMQ container
docker run -d \
  --name rabbitmq \
  --restart always \
  -p 5672:5672 \
  -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=${mq_user} \
  -e RABBITMQ_DEFAULT_PASS=${mq_password} \
  -e RABBITMQ_DEFAULT_VHOST=${mq_vhost} \
  -v $DATA_MOUNT/rabbitmq:/var/lib/rabbitmq \
  rabbitmq:3.13-management

# Wait for RabbitMQ to start
echo "Waiting for RabbitMQ to start..."
sleep 15

# Verify RabbitMQ is running
docker ps | grep rabbitmq

echo "RabbitMQ: ${mq_vhost} on port 5672 (via Docker)"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=== Data Instance Setup Complete ==="
echo "PostgreSQL: port 5432, database=${db_name}, user=${db_user}"
echo "Redis: port 6379"
echo "RabbitMQ: port 5672, vhost=${mq_vhost}, user=${mq_user}"
