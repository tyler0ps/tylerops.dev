# =============================================================================
# Security Group for Plane EC2
# =============================================================================

resource "aws_security_group" "plane" {
  name        = "plane-v2-sg"
  description = "Security group for Plane EC2 instance"
  vpc_id      = aws_vpc.main.id

  # SSH - for EC2 Instance Connect
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  # All outbound traffic (required for SSM, S3, etc.)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "plane-v2-sg"
  }
}
