# =============================================================================
# Private Route53 hosted zone for internal service discovery
# =============================================================================

resource "aws_route53_zone" "internal" {
  name    = "tylerops.internal"
  comment = "Private zone for internal service discovery"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  lifecycle {
    prevent_destroy = true
  }
}
