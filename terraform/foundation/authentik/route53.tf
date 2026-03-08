# =============================================================================
# Internal DNS record — managed by Terraform as placeholder (0.0.0.0)
# Actual IP is updated on boot via user-data (UPSERT with private IP)
# =============================================================================

resource "aws_route53_record" "authentik_internal" {
  zone_id = data.terraform_remote_state.networking.outputs.internal_zone_id
  name    = "authentik.tylerops.internal"
  type    = "A"
  ttl     = 30
  records = ["0.0.0.0"]

  lifecycle {
    ignore_changes = [records]
  }
}
