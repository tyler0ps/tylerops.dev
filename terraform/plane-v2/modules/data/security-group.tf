# =============================================================================
# Security Group for Data Instance (PostgreSQL + Redis + RabbitMQ)
# =============================================================================

resource "aws_security_group" "data" {
  name        = "${var.name_prefix}-data-sg"
  description = "Security group for data instance (PostgreSQL, Redis, RabbitMQ)"
  vpc_id      = var.vpc_id

  # PostgreSQL - only from Plane instance
  ingress {
    description     = "PostgreSQL from Plane"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.plane_security_group_id]
  }

  # Redis - only from Plane instance
  ingress {
    description     = "Redis from Plane"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.plane_security_group_id]
  }

  # RabbitMQ AMQP - only from Plane instance
  ingress {
    description     = "RabbitMQ AMQP from Plane"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [var.plane_security_group_id]
  }

  # All outbound traffic (for SSM, package updates)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-data-sg"
  }
}
