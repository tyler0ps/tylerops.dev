# =============================================================================
# Security Group for Caddy EC2
# =============================================================================

resource "aws_security_group" "caddy" {
  name        = "caddy-sg"
  description = "Security group for Caddy reverse proxy"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  # No SSH — use SSM Session Manager instead

  ingress {
    description = "HTTP (Lets Encrypt validation)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "caddy-sg"
  }
}
