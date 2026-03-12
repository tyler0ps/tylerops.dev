output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cilium.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks_cilium.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks_cilium.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks_cilium.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.eks_cilium.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = module.eks_cilium.cluster_oidc_issuer_url
}

# output "node_iam_role_name" {
#   description = "IAM role name for system nodes (attach additional policies here)"
#   value       = module.eks_cilium.node_iam_role_name
# }

output "vpc_id" {
  description = "VPC ID"
  value       = data.terraform_remote_state.networking.outputs.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for NLB)"
  value       = data.terraform_remote_state.networking.outputs.public_subnet_ids
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks_cilium.cluster_name} --region ${local.region}"
}
