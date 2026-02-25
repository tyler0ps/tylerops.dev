# =============================================================================
# Security Group for Authentik EC2
# =============================================================================

resource "aws_security_group" "authentik" {
  name        = "authentik-sg"
  description = "Security group for Authentik EC2 instance"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  # No SSH - use SSM Session Manager instead

  # HTTP - for Caddy (Let's Encrypt validation)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS - for Caddy
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
