# ============================================================
# REMOTE STATE — Conditional reads per cluster_source
# Terraform doesn't support dynamic backend keys, so both
# data sources are declared and selected via count + locals.
# ============================================================

data "terraform_remote_state" "eks_foundation" {
  count   = var.cluster_source == "eks-foundation" ? 1 : 0
  backend = "s3"
  config = {
    bucket = "generic-gha-terraform-state"
    key    = "foundation/eks/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "eks_cilium" {
  count   = var.cluster_source == "eks-cilium" ? 1 : 0
  backend = "s3"
  config = {
    bucket = "generic-gha-terraform-state"
    key    = "foundation/eks-cilium/terraform.tfstate"
    region = var.region
  }
}

# ---- SSM Secrets ----

data "aws_ssm_parameter" "argocd_dex_client_secret" {
  name            = "/terraform/eks/argocd_dex_client_secret"
  with_decryption = true
}

data "aws_ssm_parameter" "grafana_oauth_client_secret" {
  name            = "/terraform/eks/grafana_oauth_client_secret"
  with_decryption = true
}

# ---- Route53 Hosted Zone (for ACM DNS validation) ----

data "aws_route53_zone" "tylerops_dev" {
  name         = "tylerops.dev."
  private_zone = false
}
