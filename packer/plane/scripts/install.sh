#!/bin/bash
set -euo pipefail

echo "=== System update ==="
sudo dnf update -y

echo "=== Installing SSM Agent ==="
sudo dnf install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent

# =============================================================================
# Docker
# =============================================================================
echo "=== Installing Docker ==="
sudo dnf install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# =============================================================================
# Docker Buildx
# =============================================================================
echo "=== Installing Docker Buildx ==="
BUILDX_VERSION=$(curl -fsSL https://api.github.com/repos/docker/buildx/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -fsSL \
  "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-arm64" \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# =============================================================================
# Docker Compose plugin
# =============================================================================
echo "=== Installing Docker Compose ==="
COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
sudo curl -fsSL \
  "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-aarch64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# =============================================================================
# Download and install Plane Community Edition
# =============================================================================
echo "=== Installing Plane Community Edition ==="
sudo mkdir -p /opt/plane-selfhost
cd /opt/plane-selfhost

sudo curl -fsSL -o setup.sh https://github.com/makeplane/plane/releases/latest/download/setup.sh
sudo chmod +x setup.sh

# Run install (option 1) to download docker-compose.yaml and related files into plane-app/
echo "1" | sudo ./setup.sh

cd plane-app

# =============================================================================
# Patch docker-compose.yaml to use EBS bind mounts instead of named volumes
# (actual EBS mount happens at boot via user-data)
# =============================================================================
echo "=== Patching docker-compose.yaml for EBS bind mounts ==="
sudo sed -i 's|pgdata:/var/lib/postgresql/data|/opt/plane-data/postgres:/var/lib/postgresql/data|g' docker-compose.yaml
sudo sed -i 's|redisdata:/data|/opt/plane-data/redis:/data|g' docker-compose.yaml
sudo sed -i 's|uploads:/export|/opt/plane-data/minio:/export|g' docker-compose.yaml
sudo sed -i 's|proxy_data:/data|/opt/plane-data/caddy/data:/data|g' docker-compose.yaml
sudo sed -i 's|proxy_config:/config|/opt/plane-data/caddy/config:/config|g' docker-compose.yaml

# =============================================================================
# Pre-pull Docker images (faster cold-start on real instances)
# =============================================================================
echo "=== Pre-pulling Plane images ==="
# Pull all images referenced in the compose file
sudo docker compose pull || true

# =============================================================================
# Create data mount point (actual EBS mount happens at boot via user-data)
# =============================================================================
sudo mkdir -p /opt/plane-data

echo "=== Installation complete ==="
docker --version
docker compose version
