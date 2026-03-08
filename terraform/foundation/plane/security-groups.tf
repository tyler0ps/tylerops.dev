# =============================================================================
# Security Group for Plane EC2
# =============================================================================

resource "aws_security_group" "plane" {
  name        = "plane-sg"
  description = "Security group for Plane EC2 instance"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  # No SSH — use SSM Session Manager instead

  # Plane HTTP — only from Caddy reverse proxy
  ingress {
    description     = "Plane HTTP from Caddy"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.caddy.outputs.security_group_id]
  }

  # All outbound traffic (required for SSM + Docker image pulls)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "plane-sg"
  }
}
