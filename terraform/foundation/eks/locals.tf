locals {
  cluster_name      = "eks-foundation"
  cluster_version   = "1.34"
  region            = "ap-southeast-1"
  karpenter_version = "1.8.5"

  chart_versions = {
    aws_lbc      = "3.1.0"
    cert_manager = "v1.19.4"
    envoy        = "v1.6.4"
    external_dns = "1.20.0"
    argocd       = "9.4.7"
  }

  tags = {
    Project     = "eks-foundation"
    Environment = "management"
    ManagedBy   = "terraform"
    Purpose     = "shared-services"
  }
}
