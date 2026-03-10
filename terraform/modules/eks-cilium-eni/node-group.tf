resource "aws_iam_role" "system_node" {
  name = "${var.cluster_name}-system-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "system_node_worker" {
  role       = aws_iam_role.system_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "system_node_ecr" {
  role       = aws_iam_role.system_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Cilium ENI mode needs EC2 API access from every node
resource "aws_iam_role_policy" "cilium_eni_system_node" {
  name = "CiliumENIPermissions"
  role = aws_iam_role.system_node.name

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
        "ec2:DescribeTags"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_eks_node_group" "system" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.system_node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = ["m6g.medium", "m7g.medium"]
  ami_type       = "BOTTLEROCKET_ARM_64"
  capacity_type  = "SPOT"

  scaling_config {
    min_size     = 1
    max_size     = 3
    desired_size = 1
  }

  labels = {
    role                      = "system"
    "karpenter.sh/controller" = "true"
  }

  # Per Cilium docs: taint nodes so app pods don't schedule
  # until Cilium agent is ready. Cilium tolerates this taint.
  taint {
    key    = "node.cilium.io/agent-not-ready"
    value  = "true"
    effect = "NO_EXECUTE"
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(var.tags, {
    Name                     = "${var.cluster_name}-system"
    "karpenter.sh/discovery" = var.cluster_name
  })

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.system_node_worker,
    aws_iam_role_policy_attachment.system_node_ecr,
    aws_iam_role_policy.cilium_eni_system_node,
  ]
}
