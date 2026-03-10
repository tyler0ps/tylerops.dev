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

  # Addons are installed separately in addons.tf AFTER Cilium is ready.
  # Installing them here causes deadlock: EKS waits for addon pods to be
  # ACTIVE, but pods can't schedule until Cilium removes the node taint.

  tags = var.tags
}
