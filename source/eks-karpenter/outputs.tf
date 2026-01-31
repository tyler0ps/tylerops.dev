# ============================================================
# OUTPUTS - Cluster Information and Verification Commands
# ============================================================

# ============================================================
# CLUSTER INFORMATION
# ============================================================
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks.cluster_version
}

output "region" {
  description = "AWS region"
  value       = local.region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
}

# ============================================================
# KARPENTER INFORMATION
# ============================================================
output "karpenter_irsa_arn" {
  description = "ARN of IAM role for Karpenter controller"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "Name of IAM role for Karpenter-managed nodes"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "Name of SQS queue for Karpenter spot termination handling"
  value       = module.karpenter.queue_name
}

# ============================================================
# EBS CSI DRIVER INFORMATION
# ============================================================
output "ebs_csi_pod_identity_role_arn" {
  description = "ARN of IAM role for EBS CSI driver (Pod Identity)"
  value       = module.ebs_csi_pod_identity.iam_role_arn
}

# ============================================================
# KUBECONFIG COMMAND
# ============================================================
output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${local.region}"
}
