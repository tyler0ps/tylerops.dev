# ============================================================
# KARPENTER - IAM + SQS via EKS module submodule
# Uses Pod Identity (EKS module v21 default, replaces IRSA)
# ============================================================
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = module.eks.cluster_name

  create_node_iam_role            = true
  create_pod_identity_association = true

  enable_spot_termination = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  # node_iam_role_additional_policies = {
  #   AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  # }

  tags = var.tags

  depends_on = [
    module.eks,
    helm_release.cilium,
  ]
}

# ============================================================
# KARPENTER HELM INSTALLATION
# ============================================================
resource "helm_release" "karpenter" {
  namespace        = "kube-system"
  create_namespace = false
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  wait             = false

  values = [
    <<-EOT
    replicaCount: 1

    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}

    controller:
      resources:
        requests:
          cpu: 200m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi

    webhook:
      enabled: false
    EOT
  ]

  depends_on = [
    module.karpenter,
  ]
}
