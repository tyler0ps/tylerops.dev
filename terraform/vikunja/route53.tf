# =============================================================================
# Route53 DNS Record
# =============================================================================

# Reference existing hosted zone
data "aws_route53_zone" "main" {
  name = "tylerops.dev"
}

# A record for task.tylerops.dev
resource "aws_route53_record" "vikunja" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.vikunja.public_ip]
}
