# ============================================================
# EKS ADDONS - installed AFTER Cilium is ready
#
# Why not in module "eks":
#   aws_eks_addon waits for addon status = ACTIVE, which requires
#   pods to be Running. Pods can't schedule until Cilium removes
#   the node.cilium.io/agent-not-ready taint — deadlock.
#
# Order: Cilium ready → taint removed → pods schedule → ACTIVE
# ============================================================

resource "aws_eks_addon" "coredns" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "coredns"
  addon_version = "v1.13.2-eksbuild.1"

  configuration_values = jsonencode({ replicaCount = 1 })

  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [helm_release.cilium]
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.10-eksbuild.2"

  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [helm_release.cilium]
}

resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.56.0-eksbuild.1"

  configuration_values = jsonencode({ controller = { replicaCount = 1 } })

  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    helm_release.cilium,
    aws_eks_addon.eks_pod_identity_agent,
  ]
}
