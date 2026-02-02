#!/bin/bash
set -e

# =============================================================================
# Vikunja EC2 Bootstrap Script
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Vikunja setup ==="

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
# Install Caddy (direct binary - COPR doesn't support Amazon Linux 2023)
# =============================================================================
echo "=== Installing Caddy ==="

# Download latest Caddy binary
CADDY_VERSION=$(curl -s https://api.github.com/repos/caddyserver/caddy/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
echo "Installing Caddy version: $CADDY_VERSION"

curl -LO "https://github.com/caddyserver/caddy/releases/download/v$CADDY_VERSION/caddy_$${CADDY_VERSION}_linux_amd64.tar.gz"
tar -xzf "caddy_$${CADDY_VERSION}_linux_amd64.tar.gz" caddy
mv caddy /usr/bin/caddy
chmod +x /usr/bin/caddy

# Create caddy user and group
groupadd --system caddy
useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin caddy

# Create config directory
mkdir -p /etc/caddy

# Configure Caddy
cat > /etc/caddy/Caddyfile <<'EOF'
${domain} {
    reverse_proxy localhost:3456
}
EOF

# Create systemd service for Caddy
cat > /etc/systemd/system/caddy.service <<'EOF'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# =============================================================================
# Install Vikunja
# =============================================================================
echo "=== Installing Vikunja ==="

# Create vikunja user
useradd -r -s /sbin/nologin vikunja

# Create directories
mkdir -p /opt/vikunja
mkdir -p /opt/vikunja/files

# Download Vikunja
VIKUNJA_VERSION="v1.0.0"
echo "Installing Vikunja version: $VIKUNJA_VERSION"

cd /tmp
curl -LO "https://dl.vikunja.io/vikunja/$VIKUNJA_VERSION/vikunja-$VIKUNJA_VERSION-linux-amd64-full.zip"
dnf install -y unzip
unzip -o "vikunja-$VIKUNJA_VERSION-linux-amd64-full.zip" -d /opt/vikunja
mv /opt/vikunja/vikunja-$VIKUNJA_VERSION-linux-amd64 /opt/vikunja/vikunja
chmod +x /opt/vikunja/vikunja

# Create Vikunja config
cat > /opt/vikunja/config.yaml <<'EOF'
service:
  publicurl: "https://${domain}/"
  jwtsecret: "${jwt_secret}"
  frontendurl: "https://${domain}/"
  enableregistration: true

database:
  type: sqlite
  path: "/opt/vikunja/vikunja.db"

files:
  basepath: "/opt/vikunja/files"

log:
  enabled: true
  path: "/opt/vikunja/logs"
  standard: "stdout"
  level: "INFO"
EOF

# Create logs directory
mkdir -p /opt/vikunja/logs

# Set ownership
chown -R vikunja:vikunja /opt/vikunja

# Create systemd service
cat > /etc/systemd/system/vikunja.service <<'EOF'
[Unit]
Description=Vikunja
After=network.target

[Service]
Type=simple
User=vikunja
Group=vikunja
WorkingDirectory=/opt/vikunja
ExecStart=/opt/vikunja/vikunja
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# =============================================================================
# Start Services
# =============================================================================
echo "=== Starting services ==="

systemctl daemon-reload
systemctl enable vikunja
systemctl start vikunja

systemctl enable caddy
systemctl start caddy

echo "=== Vikunja setup complete ==="
echo "Access at: https://${domain}"
