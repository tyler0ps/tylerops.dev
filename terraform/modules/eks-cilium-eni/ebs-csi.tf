# ============================================================
# EBS CSI DRIVER - Pod Identity IAM Configuration
# ============================================================

module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "${var.cluster_name}-ebs-csi"

  attach_aws_ebs_csi_policy = true

  associations = {
    ebs-csi = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = var.tags
}
