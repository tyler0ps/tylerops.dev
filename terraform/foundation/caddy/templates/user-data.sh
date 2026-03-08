#!/bin/bash
set -e

# =============================================================================
# Caddy Reverse Proxy Bootstrap Script (AMI-based)
# Caddy binary and systemd service are already in the AMI.
# This script: updates Route53 with public IP, writes Caddyfile, starts Caddy.
# =============================================================================

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Caddy (AMI-based boot, ASG mode) ==="
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
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Public IP: $PUBLIC_IP"

# =============================================================================
# Update Route53 record with current public IP
# =============================================================================
echo "=== Updating Route53 ==="

aws route53 change-resource-record-sets \
  --hosted-zone-id "${hosted_zone_id}" \
  --change-batch "{
    \"Changes\": [
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"${atlantis_domain}\",
          \"Type\": \"A\",
          \"TTL\": 300,
          \"ResourceRecords\": [{\"Value\": \"$PUBLIC_IP\"}]
        }
      },
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"${authentik_domain}\",
          \"Type\": \"A\",
          \"TTL\": 300,
          \"ResourceRecords\": [{\"Value\": \"$PUBLIC_IP\"}]
        }
      }
    ]
  }"
echo "Route53 updated: ${atlantis_domain}, ${authentik_domain} → $PUBLIC_IP"

# =============================================================================
# Read basic auth credentials from SSM
# =============================================================================
echo "=== Reading basic auth credentials ==="

BASIC_AUTH_USER=$(aws ssm get-parameter \
  --name "/caddy/atlantis_basic_auth_user" \
  --query Parameter.Value --output text \
  --region ${aws_region})

BASIC_AUTH_HASH=$(aws ssm get-parameter \
  --name "/caddy/atlantis_basic_auth_hash" \
  --with-decryption \
  --query Parameter.Value --output text \
  --region ${aws_region})

# =============================================================================
# Write Caddyfile
# /events proxied without auth (Atlantis authenticates via webhook secret)
# /* protected by Authentik forward auth
# =============================================================================
echo "=== Writing Caddyfile ==="

cat > /etc/caddy/Caddyfile << EOF
{
    email ${acme_email}

    storage s3 {
        host             s3.${aws_region}.amazonaws.com
        bucket           ${cert_bucket}
        region           ${aws_region}
        prefix           caddy/
        use_iam_provider true
    }
}

${atlantis_domain} {
    route {
        # Webhook endpoint — authenticated by Atlantis webhook secret, no basic auth
        handle /events {
            reverse_proxy atlantis.tylerops.internal:4141
        }

        # UI — protected by basic auth
        basic_auth {
            $BASIC_AUTH_USER $BASIC_AUTH_HASH
        }

        reverse_proxy atlantis.tylerops.internal:4141
    }
}

${authentik_domain} {
    reverse_proxy authentik.tylerops.internal:9000
}
EOF

# =============================================================================
# Start Caddy
# =============================================================================
echo "=== Starting Caddy ==="
systemctl enable caddy
systemctl restart caddy

echo "=== Caddy startup complete ==="
echo "Proxying: https://${atlantis_domain} → atlantis.tylerops.internal:4141"
