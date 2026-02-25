# Reference existing hosted zone in management account (centralized DNS)
data "aws_route53_zone" "main" {
  provider = aws.management
  name     = var.domain_name
}

# A record for apex domain → prod CloudFront
resource "aws_route53_record" "apex" {
  provider        = aws.management
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# A record for www → prod CloudFront
resource "aws_route53_record" "www" {
  provider        = aws.management
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = "www.${var.domain_name}"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
