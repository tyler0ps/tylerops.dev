# =============================================================================
# Route53 DNS Record
# =============================================================================

resource "aws_route53_record" "authentik" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.authentik.public_ip]
}

resource "aws_route53_record" "plane" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name_plane
  type    = "A"
  ttl     = 300
  records = [aws_eip.authentik.public_ip]
}
