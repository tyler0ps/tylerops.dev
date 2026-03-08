# =============================================================================
# Security Group for Authentik EC2
# =============================================================================

resource "aws_security_group" "authentik" {
  name        = "authentik-sg"
  description = "Security group for Authentik EC2 instance"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  # No SSH — use SSM Session Manager instead

  # Authentik HTTP — only from Caddy reverse proxy
  ingress {
    description     = "Authentik HTTP from Caddy"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.caddy.outputs.security_group_id]
  }

  # All outbound traffic (required for SSM + package installs)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "authentik-sg"
  }
}
