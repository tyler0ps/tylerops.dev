# ============================================================
# EBS CSI DRIVER - Pod Identity IAM Configuration
# ============================================================
# Configures Pod Identity IAM for the EBS CSI driver addon
# Uses Pod Identity instead of IRSA for streamlined IAM

module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.6"

  name = "${local.cluster_name}-ebs-csi"

  # Attach AWS managed EBS CSI policy
  attach_aws_ebs_csi_policy = true

  # Pod Identity association
  associations = {
    ebs-csi = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = local.tags
}
