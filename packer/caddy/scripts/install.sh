#!/bin/bash
set -euo pipefail

echo "=== Installing SSM Agent ==="
sudo dnf install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent

echo "=== Updating system ==="
sudo dnf update -y
sudo dnf install -y --allowerasing curl

# =============================================================================
# Install Caddy with certmagic-s3 module (S3 TLS storage for spot instances)
# Uses Caddy's download API to get a custom build — no Go/xcaddy needed
# =============================================================================
echo "=== Downloading Caddy with certmagic-s3 via Caddy download API ==="
curl -fsSL \
  "https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com%2Fss098%2Fcertmagic-s3" \
  -o /tmp/caddy
sudo install -m 755 /tmp/caddy /usr/local/bin/caddy
rm -f /tmp/caddy

# =============================================================================
# System setup
# =============================================================================
echo "=== Creating caddy user and directories ==="
sudo useradd --system --home /var/lib/caddy --shell /usr/sbin/nologin caddy 2>/dev/null || true

sudo mkdir -p /etc/caddy /var/log/caddy /var/lib/caddy
sudo chown -R caddy:caddy /var/lib/caddy /var/log/caddy

# Create placeholder Caddyfile (overwritten by user-data at boot)
sudo tee /etc/caddy/Caddyfile > /dev/null << 'EOF'
# Placeholder — replaced by user-data on first boot
:80 {
    respond "Caddy not yet configured" 503
}
EOF
sudo chown caddy:caddy /etc/caddy/Caddyfile

# Systemd service
sudo tee /etc/systemd/system/caddy.service > /dev/null << 'EOF'
[Unit]
Description=Caddy reverse proxy
Documentation=https://caddyserver.com/docs/
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile --adapter caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/var/lib/caddy /var/log/caddy /etc/caddy
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

echo "=== Caddy installed successfully ==="
caddy version
caddy list-modules | grep s3
