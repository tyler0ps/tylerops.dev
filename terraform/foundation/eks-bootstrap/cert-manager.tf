# ============================================================
# CERT-MANAGER — Pod Identity
# ============================================================

locals {
  cert_manager_namespace       = "cert-manager"
  cert_manager_service_account = "cert-manager"
}

module "cert_manager_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.6"

  name                       = "${local.cluster_name}-cert-manager"
  attach_cert_manager_policy = true

  cert_manager_hosted_zone_arns = [data.aws_route53_zone.tylerops_dev.arn]

  associations = {
    cert-manager = {
      cluster_name    = local.cluster_name
      namespace       = local.cert_manager_namespace
      service_account = local.cert_manager_service_account
    }
  }

  tags = local.tags
}
