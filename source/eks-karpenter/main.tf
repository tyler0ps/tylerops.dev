# ============================================================
# KARPENTER EXPERIMENT - MAIN INFRASTRUCTURE
# ============================================================
# Independent EKS cluster for experimenting with Karpenter
# Based on: https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/

# ============================================================
# VPC - Dedicated network for the experiment
# ============================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs

  # NAT Gateway for private subnets (cost optimization: single NAT)
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # DNS support required for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags for EKS and Karpenter discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "karpenter.sh/discovery"                      = local.cluster_name
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "karpenter.sh/discovery"                      = local.cluster_name
  }

  tags = local.tags
}

# ============================================================
# EKS CLUSTER
# ============================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  # VPC configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IRSA (IAM Roles for Service Accounts) - required for Karpenter
  enable_irsa = true

  # Allow current user to administer the cluster
  enable_cluster_creator_admin_permissions = true

  # Grant GitHub Actions role access to the cluster
  access_entries = {
    github_actions = {
      principal_arn = "arn:aws:iam::382027875658:role/github-actions-terraform-role"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Tag the node security group for Karpenter discovery
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  # ============================================================
  # MANAGED NODE GROUP - For Karpenter Controller
  # ============================================================
  # Small node group to run the Karpenter controller itself
  # Karpenter will manage all other nodes
  eks_managed_node_groups = {
    karpenter = {
      # Instance configuration
      instance_types = ["m5.large"]
      capacity_type  = "SPOT" # Use spot for cost savings

      # Minimal size - just enough for Karpenter
      min_size     = 1
      max_size     = 3
      desired_size = 1

      # Labels to identify these nodes
      labels = {
        role                      = "karpenter-controller"
        "karpenter.sh/controller" = "true"
      }

      # Tags for Karpenter discovery
      tags = {
        "karpenter.sh/discovery" = local.cluster_name
      }
    }
  }

  # ============================================================
  # CLUSTER ADD-ONS
  # ============================================================
  # Essential add-ons for cluster operation
  cluster_addons = {
    # CoreDNS - DNS resolution for services
    coredns = {
      most_recent = true
    }

    # EKS Pod Identity Agent - For IAM roles
    eks-pod-identity-agent = {
      most_recent = true
    }

    # Kube-proxy - Network proxy
    kube-proxy = {
      most_recent = true
    }

    # VPC CNI - Networking plugin
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          # Enable prefix delegation for more IPs per node
          ENABLE_PREFIX_DELEGATION = "true"
          # Enable custom networking if needed
          # AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
        }
      })
    }
  }

  tags = local.tags
}
