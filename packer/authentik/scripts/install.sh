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
# Authentik compose.yml
# =============================================================================
echo "=== Writing Authentik compose.yml ==="
sudo mkdir -p /opt/authentik

sudo tee /opt/authentik/compose.yml > /dev/null << 'EOF'
services:
  postgresql:
    image: postgres:16-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 5s
    volumes:
      - /opt/authentik-data/postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${PG_PASS:?PG_PASS required}
      POSTGRES_USER: ${PG_USER:-authentik}
      POSTGRES_DB: ${PG_DB:-authentik}

  redis:
    image: redis:alpine
    restart: unless-stopped
    command: --save 60 1 --loglevel warning
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 3s
    volumes:
      - /opt/authentik-data/redis:/data

  server:
    image: ghcr.io/goauthentik/server:${AUTHENTIK_TAG:-2026.2.0}
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: ${PG_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: ${PG_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: ${PG_PASS:?PG_PASS required}
    volumes:
      - /opt/authentik-data/media:/media
      - /opt/authentik-data/custom-templates:/templates
    env_file:
      - /opt/authentik/.env
    ports:
      - "9000:9000"
    depends_on:
      postgresql:
        condition: service_healthy
      redis:
        condition: service_healthy

  worker:
    image: ghcr.io/goauthentik/server:${AUTHENTIK_TAG:-2026.2.0}
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: ${PG_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: ${PG_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: ${PG_PASS:?PG_PASS required}
    volumes:
      - /opt/authentik-data/media:/media
      - /opt/authentik-data/certs:/certs
      - /opt/authentik-data/custom-templates:/templates
    env_file:
      - /opt/authentik/.env
    depends_on:
      postgresql:
        condition: service_healthy
      redis:
        condition: service_healthy
EOF

# =============================================================================
# Pre-pull Docker images (faster cold-start on real instances)
# =============================================================================
echo "=== Pre-pulling Authentik images ==="
AUTHENTIK_TAG="2026.2.0"
sudo docker pull postgres:16-alpine
sudo docker pull redis:alpine
sudo docker pull ghcr.io/goauthentik/server:${AUTHENTIK_TAG}

# =============================================================================
# Create data mount point (actual EBS mount happens at boot via user-data)
# =============================================================================
sudo mkdir -p /opt/authentik-data

echo "=== Installation complete ==="
docker --version
docker compose version
