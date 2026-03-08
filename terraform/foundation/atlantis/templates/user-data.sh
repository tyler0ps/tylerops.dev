#!/bin/bash
set -e

# =============================================================================
# Atlantis Bootstrap Script (AMI-based)
# Atlantis binary and systemd service are already in the AMI.
# This script: registers internal DNS, reads credentials from SSM, starts Atlantis.
#
# Required SSM parameters (create manually before first apply):
#   /atlantis/gh_app_id          — GitHub App ID (String)
#   /atlantis/gh_app_key         — GitHub App private key PEM (SecureString)
#   /atlantis/gh_webhook_secret  — Webhook secret (SecureString)
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Atlantis (AMI-based boot) ==="
echo "Timestamp: $(date)"

# SSM Agent
systemctl start amazon-ssm-agent || true

echo "=== Setting up swap ==="
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "Swap enabled"
else
  echo "Swap already active"
fi

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
# Register Internal DNS
# Caddy resolves atlantis.tylerops.internal to route traffic to this instance.
# TTL=30 ensures fast failover on spot replacement.
# =============================================================================
echo "=== Registering internal DNS ==="

ZONE_ID="${internal_zone_id}"

aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"atlantis.tylerops.internal\",
        \"Type\": \"A\",
        \"TTL\": 30,
        \"ResourceRecords\": [{\"Value\": \"$PRIVATE_IP\"}]
      }
    }]
  }" \
  --region ${aws_region}

echo "Internal DNS registered: atlantis.tylerops.internal -> $PRIVATE_IP"

# =============================================================================
# Read GitHub App credentials from SSM
# =============================================================================
echo "=== Reading credentials from SSM ==="

GH_APP_ID=$(aws ssm get-parameter \
  --name "/atlantis/gh_app_id" \
  --query Parameter.Value --output text \
  --region ${aws_region})

GH_WEBHOOK_SECRET=$(aws ssm get-parameter \
  --name "/atlantis/gh_webhook_secret" \
  --with-decryption \
  --query Parameter.Value --output text \
  --region ${aws_region})

# Write GitHub App private key
aws ssm get-parameter \
  --name "/atlantis/gh_app_key" \
  --with-decryption \
  --query Parameter.Value --output text \
  --region ${aws_region} > /opt/atlantis/gh-app-key.pem

chmod 600 /opt/atlantis/gh-app-key.pem
chown atlantis:atlantis /opt/atlantis/gh-app-key.pem

echo "Credentials loaded"

# =============================================================================
# Write Atlantis environment file
# =============================================================================
echo "=== Writing Atlantis config ==="

cat > /opt/atlantis/atlantis.env << EOF
ATLANTIS_GH_APP_ID=$GH_APP_ID
ATLANTIS_GH_APP_KEY_FILE=/opt/atlantis/gh-app-key.pem
ATLANTIS_GH_WEBHOOK_SECRET=$GH_WEBHOOK_SECRET
ATLANTIS_WRITE_GIT_CREDS=true
ATLANTIS_REPO_ALLOWLIST=${repo_allowlist}
ATLANTIS_ATLANTIS_URL=https://${atlantis_domain}
ATLANTIS_PORT=4141
ATLANTIS_REPO_CONFIG=/opt/atlantis/server-atlantis.yaml
AWS_REGION=${aws_region}
AWS_DEFAULT_REGION=${aws_region}
EOF

chmod 600 /opt/atlantis/atlantis.env
chown atlantis:atlantis /opt/atlantis/atlantis.env

# =============================================================================
# Write Atlantis server-side config
# =============================================================================

cat > /opt/atlantis/server-atlantis.yaml << 'SERVERCONF'
repos:
  - id: /.*/
    apply_requirements: [approved, mergeable]
    allowed_overrides: [apply_requirements]
    allow_custom_workflows: false
SERVERCONF

chown atlantis:atlantis /opt/atlantis/server-atlantis.yaml

# =============================================================================
# Start Atlantis
# =============================================================================
echo "=== Starting Atlantis ==="
systemctl enable atlantis
systemctl restart atlantis

echo "=== Atlantis startup complete ==="
echo "Listening on: http://$PRIVATE_IP:4141 (internal)"
echo "Public URL: https://${atlantis_domain}"
