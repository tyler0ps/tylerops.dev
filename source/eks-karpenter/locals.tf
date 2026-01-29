# Local variables for Karpenter experiment
locals {
  # Cluster configuration
  cluster_name    = "karpenter-experiment"
  cluster_version = "1.34"

  # AWS region and availability zones
  region = "ap-southeast-1"
  azs    = ["ap-southeast-1a", "ap-southeast-1b"]

  # VPC configuration
  vpc_cidr             = "10.2.0.0/16"
  private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]
  public_subnet_cidrs  = ["10.2.101.0/24", "10.2.102.0/24"]

  # Karpenter configuration
  karpenter_version   = "1.8.5"
  karpenter_namespace = "kube-system"

  # Tags applied to all resources
  tags = {
    Project     = "karpenter-experiment"
    Environment = "experiment"
    ManagedBy   = "terraform"
    Purpose     = "learning-karpenter"
  }
}
