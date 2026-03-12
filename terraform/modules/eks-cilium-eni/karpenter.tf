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

  namespace = var.karpenter_namespace

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags

  depends_on = [
    module.eks,
  ]
}

# Cilium ENI mode requires EC2 API access from every node,
# including Karpenter-launched nodes (same as system_node role in node-group.tf).
resource "aws_iam_role_policy" "cilium_eni_karpenter_node" {
  name = "CiliumENIPermissions"
  role = module.karpenter.node_iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceTypes",
        "ec2:CreateNetworkInterface",
        "ec2:AttachNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DetachNetworkInterface",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses",
        "ec2:CreateTags",
        "ec2:DescribeTags",
      ]
      Resource = "*"
    }]
  })
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
    nodeSelector:
      karpenter.sh/controller: 'true'
    replicas: 1

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
