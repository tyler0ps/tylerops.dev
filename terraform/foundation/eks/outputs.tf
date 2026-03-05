output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_karpenter.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks_karpenter.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks_karpenter.cluster_version
}

output "karpenter_irsa_arn" {
  description = "ARN of IAM role for Karpenter controller"
  value       = module.eks_karpenter.karpenter_irsa_arn
}

output "karpenter_node_iam_role_name" {
  description = "Name of IAM role for Karpenter-managed nodes"
  value       = module.eks_karpenter.karpenter_node_iam_role_name
}

output "karpenter_queue_name" {
  description = "SQS queue name for Karpenter spot termination handling"
  value       = module.eks_karpenter.karpenter_queue_name
}

output "ebs_csi_pod_identity_role_arn" {
  description = "ARN of IAM role for EBS CSI driver"
  value       = module.eks_karpenter.ebs_csi_pod_identity_role_arn
}

output "cert_manager_irsa_arn" {
  description = "ARN of IAM role for cert-manager"
  value       = aws_iam_role.cert_manager.arn
}

output "external_dns_irsa_arn" {
  description = "ARN of IAM role for external-dns"
  value       = aws_iam_role.external_dns.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = data.terraform_remote_state.networking.outputs.vpc_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks_karpenter.cluster_name} --region ap-southeast-1"
}
