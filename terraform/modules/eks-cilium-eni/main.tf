# ============================================================
# EKS CLUSTER WITH CILIUM ENI MODE
# ============================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  endpoint_public_access  = true
  endpoint_private_access = true

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

  node_security_group_additional_rules = {
    ingress_nlb_envoy = {
      description = "Allow NLB health checks and traffic to Envoy Gateway"
      protocol    = "tcp"
      from_port   = 10080
      to_port     = 10080
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

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

      taints = {
        CriticalAddonsOnly = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      tags = {
        "karpenter.sh/discovery" = var.cluster_name
      }
    }
  }

  # ============================================================
  # CLUSTER ADD-ONS
  # ============================================================
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }

    # aws-ebs-csi-driver = {
    #   addon_version        = "v1.55.0-eksbuild.1"
    #   configuration_values = jsonencode({ controller = { replicaCount = 1 } })
    # }
  }

  tags = var.tags
}
