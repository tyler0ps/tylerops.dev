# =============================================================================
# Private Hosted Zone and DNS Records
# =============================================================================

resource "aws_route53_zone" "private" {
  name = var.private_zone_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = {
    Name = "${var.name_prefix}-private-zone"
  }
}

# PostgreSQL DNS
resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.${var.private_zone_name}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.data.private_ip]
}

# Redis DNS
resource "aws_route53_record" "redis" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "redis.${var.private_zone_name}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.data.private_ip]
}

# RabbitMQ DNS
resource "aws_route53_record" "mq" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "mq.${var.private_zone_name}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.data.private_ip]
}
