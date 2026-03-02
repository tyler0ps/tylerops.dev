locals {
  cluster_name      = "eks-foundation"
  cluster_version   = "1.34"
  region            = "ap-southeast-1"
  karpenter_version = "1.8.5"

  tags = {
    Project     = "eks-foundation"
    Environment = "management"
    ManagedBy   = "terraform"
    Purpose     = "shared-services"
  }
}
