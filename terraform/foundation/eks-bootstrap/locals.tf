locals {
  # Normalize cluster identity from whichever remote state is active
  _rs = var.cluster_source == "eks-foundation" ? (
    data.terraform_remote_state.eks_foundation[0].outputs
    ) : (
    data.terraform_remote_state.eks_cilium[0].outputs
  )

  cluster_name                       = local._rs.cluster_name
  cluster_endpoint                   = local._rs.cluster_endpoint
  cluster_certificate_authority_data = local._rs.cluster_certificate_authority_data
  oidc_provider_arn                  = local._rs.oidc_provider_arn
  cluster_oidc_issuer_url            = local._rs.cluster_oidc_issuer_url
  oidc_url_stripped                  = trimprefix(local._rs.cluster_oidc_issuer_url, "https://")
  vpc_id                             = local._rs.vpc_id
  public_subnet_ids                  = local._rs.public_subnet_ids

  # Chart versions — latest stable as of 2026-03
  chart_versions = {
    aws_lbc               = "3.1.0"   # https://github.com/aws/eks-charts
    envoy                 = "v1.7.0"  # https://github.com/envoyproxy/gateway/releases
    external_dns          = "1.20.0"  # https://github.com/kubernetes-sigs/external-dns
    argocd                = "9.4.9"   # https://github.com/argoproj/argo-helm
    kube_prometheus_stack = "82.10.2" # https://github.com/prometheus-community/helm-charts
    loki                  = "6.53.0"  # https://github.com/grafana/loki
    alloy                 = "1.6.1"   # https://github.com/grafana/alloy
    cert_manager          = "v1.19.4"
  }

  tags = merge({
    Project     = "eks-bootstrap"
    ClusterName = local.cluster_name
    Environment = "management"
    ManagedBy   = "terraform"
  }, var.tags)
}
