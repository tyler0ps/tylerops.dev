#!/bin/bash
set -euo pipefail

echo "=== Installing SSM Agent ==="
sudo dnf install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent

echo "=== Installing Atlantis + Terraform ==="

# Update system
sudo dnf update -y
sudo dnf install -y --allowerasing git unzip curl

# =============================================================================
# Install Atlantis
# =============================================================================
ATLANTIS_VERSION="0.40.0"
ARCH="arm64"

curl -fsSL \
  "https://github.com/runatlantis/atlantis/releases/download/v${ATLANTIS_VERSION}/atlantis_linux_${ARCH}.zip" \
  -o /tmp/atlantis.zip

unzip -o /tmp/atlantis.zip -d /tmp atlantis
sudo install -m 755 /tmp/atlantis /usr/local/bin/atlantis
rm -f /tmp/atlantis.zip /tmp/atlantis

# =============================================================================
# Install Terraform
# =============================================================================
TERRAFORM_VERSION="1.14.6"

curl -fsSL \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_arm64.zip" \
  -o /tmp/terraform.zip

unzip -o /tmp/terraform.zip -d /tmp terraform
sudo install -m 755 /tmp/terraform /usr/local/bin/terraform
rm -f /tmp/terraform.zip /tmp/terraform

# =============================================================================
# Create atlantis system user and directories
# =============================================================================
sudo useradd --system --home /opt/atlantis --shell /usr/sbin/nologin atlantis 2>/dev/null || true
sudo mkdir -p /opt/atlantis /var/log/atlantis
sudo chown -R atlantis:atlantis /opt/atlantis /var/log/atlantis

# Create placeholder env file (overwritten by user-data at boot)
sudo tee /opt/atlantis/atlantis.env > /dev/null << 'EOF'
# Placeholder — replaced by user-data on first boot
EOF
sudo chmod 600 /opt/atlantis/atlantis.env
sudo chown atlantis:atlantis /opt/atlantis/atlantis.env

# =============================================================================
# Systemd service
# =============================================================================
sudo tee /etc/systemd/system/atlantis.service > /dev/null << 'EOF'
[Unit]
Description=Atlantis Terraform PR automation
Documentation=https://www.runatlantis.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=atlantis
Group=atlantis
EnvironmentFile=/opt/atlantis/atlantis.env
ExecStart=/usr/local/bin/atlantis server
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=atlantis
WorkingDirectory=/opt/atlantis

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

echo "=== Installation complete ==="
atlantis version
terraform version
