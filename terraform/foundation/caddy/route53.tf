# =============================================================================
# Route53 DNS — public records managed by user-data on boot (dynamic public IP)
# Placeholders here; actual IPs set via UPSERT at instance boot.
# =============================================================================

# resource "aws_route53_record" "atlantis" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = var.atlantis_domain
#   type    = "A"
#   ttl     = 300
#   records = ["0.0.0.0"]

#   lifecycle {
#     ignore_changes = [records]
#   }
# }

# resource "aws_route53_record" "authentik" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = var.authentik_domain
#   type    = "A"
#   ttl     = 300
#   records = ["0.0.0.0"]

#   lifecycle {
#     ignore_changes = [records]
#   }
# }
