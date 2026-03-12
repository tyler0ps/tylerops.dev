locals {
  cluster_name    = "eks-cilium"
  cluster_version = "1.34"
  region          = "ap-southeast-1"

  cilium_version    = "1.19.1"
  karpenter_version = "1.9.0"

  tags = {
    Project     = "eks-cilium"
    Environment = "management"
    ManagedBy   = "terraform"
  }
}
