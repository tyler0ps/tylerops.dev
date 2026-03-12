# ============================================================
# ACM CERTIFICATE
# Wildcard cert for *.tylerops.dev, validated via Route53 DNS.
# TLS terminates at the NLB (not at Envoy Gateway).
# ============================================================

resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.tylerops.dev"
  subject_alternative_names = ["tylerops.dev"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.tylerops_dev.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}
