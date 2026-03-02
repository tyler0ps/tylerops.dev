# ============================================================
# KARPENTER EXPERIMENT - MAIN INFRASTRUCTURE
# ============================================================

# ============================================================
# EKS CLUSTER
# ============================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  enable_cluster_creator_admin_permissions = true

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

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  # ============================================================
  # MANAGED NODE GROUP - For Karpenter Controller
  # ============================================================
  eks_managed_node_groups = {
    karpenter = {
      instance_types = ["m6g.medium", "m7g.medium"]
      ami_type       = "BOTTLEROCKET_ARM_64"
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 3
      desired_size = 1

      labels = {
        role                      = "karpenter-controller"
        "karpenter.sh/controller" = "true"
      }

      tags = {
        "karpenter.sh/discovery" = var.cluster_name
      }
    }
  }

  # ============================================================
  # CLUSTER ADD-ONS
  # ============================================================
  cluster_addons = {
    coredns = {
      most_recent = true
    }

    eks-pod-identity-agent = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      })
    }

    aws-ebs-csi-driver = {
      addon_version = "v1.55.0-eksbuild.1"
    }
  }

  tags = var.tags
}
