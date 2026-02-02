# =============================================================================
# Security Group for Plane EC2
# =============================================================================

resource "aws_security_group" "plane" {
  name        = "plane-sg"
  description = "Security group for Plane EC2 instance"
  vpc_id      = aws_vpc.main.id

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

  # All outbound traffic (required for SSM)
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
