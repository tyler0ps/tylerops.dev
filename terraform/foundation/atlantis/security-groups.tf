# =============================================================================
# Security Group for Atlantis EC2 (private subnet)
# =============================================================================

resource "aws_security_group" "atlantis" {
  name        = "atlantis-sg"
  description = "Security group for Atlantis (private subnet, inbound from Caddy only)"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  # No SSH — use SSM Session Manager instead

  # Atlantis port — only reachable from Caddy reverse proxy
  ingress {
    description     = "Atlantis from Caddy"
    from_port       = 4141
    to_port         = 4141
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.caddy.outputs.security_group_id]
  }

  # All outbound — required for GitHub API, AWS APIs via NAT instance
  egress {
    description = "All outbound via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "atlantis-sg"
  }
}
