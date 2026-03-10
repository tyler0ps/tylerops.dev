# ============================================================
# OUTPUTS
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

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
}

output "ebs_csi_pod_identity_role_arn" {
  description = "ARN of IAM role for EBS CSI driver (Pod Identity)"
  value       = module.ebs_csi_pod_identity.iam_role_arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "node_iam_role_name" {
  description = "IAM role name for system nodes (attach additional policies here)"
  value       = aws_iam_role.system_node.name
}
