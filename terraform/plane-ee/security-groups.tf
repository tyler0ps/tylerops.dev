# =============================================================================
# Security Group for Plane EE
# =============================================================================

resource "aws_security_group" "plane_ee" {
  name        = "plane-ee-sg"
  description = "Security group for Plane EE (HTTP/HTTPS + SSM)"
  vpc_id      = data.aws_vpc.plane.id

  # Egress only - SSM, docker pull, package install
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

  tags = {
    Name = "plane-ee-sg"
  }
}
