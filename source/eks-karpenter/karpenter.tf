# ============================================================
# KARPENTER - Cost-optimized autoscaling for Kubernetes
# ============================================================
# Karpenter automatically provisions and manages nodes based on
# workload requirements, optimizing for cost and performance

# ============================================================
# KARPENTER IAM AND INFRASTRUCTURE
# ============================================================
# This module creates:
# - IRSA role for Karpenter controller
# - Node IAM role for Karpenter-managed nodes
# - Instance profile for EC2 instances
# - SQS queue for spot interruption handling
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # Enable IRSA for Karpenter controller
  enable_irsa                     = true
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["${local.karpenter_namespace}:karpenter"]

  # Create a separate node IAM role for Karpenter-managed nodes
  # This is separate from the managed node group role
  create_node_iam_role = true

  # Enable SQS queue for Spot interruption handling
  enable_spot_termination = true

  tags = local.tags
}

# ============================================================
# KARPENTER HELM INSTALLATION
# ============================================================
# Install Karpenter via Helm chart
resource "helm_release" "karpenter" {
  namespace        = local.karpenter_namespace
  create_namespace = false # kube-system already exists
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = local.karpenter_version
  wait             = false

  # Karpenter configuration values
  values = [
    <<-EOT
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}

    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}

    controller:
      resources:
        requests:
          cpu: 500m
          memory: 512Mi
        limits:
          cpu: 1000m
          memory: 1Gi

    # Webhook validation (disabled for simplicity)
    webhook:
      enabled: false
    EOT
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

# ============================================================
# ADDITIONAL IAM PERMISSIONS FOR KARPENTER
# ============================================================
# The Karpenter module doesn't include all required permissions
# Add missing IAM permissions for instance profile management
resource "aws_iam_role_policy" "karpenter_additional_permissions" {
  name = "KarpenterAdditionalPermissions"
  role = split("/", module.karpenter.iam_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:ListInstanceProfiles",
          "iam:GetInstanceProfile"
        ]
        Resource = "*"
      }
    ]
  })
}
