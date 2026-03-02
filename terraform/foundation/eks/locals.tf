locals {
  cluster_name      = "karpenter-experiment"
  cluster_version   = "1.34"
  region            = "ap-southeast-1"
  karpenter_version = "1.8.5"

  tags = {
    Project     = "karpenter-experiment"
    Environment = "experiment"
    ManagedBy   = "terraform"
    Purpose     = "learning-karpenter"
  }
}
