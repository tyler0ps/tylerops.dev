variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "pod_subnet_ids" {
  description = "List of subnet IDs for Cilium ENI pod IPs (secondary CIDR, e.g. 100.64.0.0/16)"
  type        = list(string)
}

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.19.1"
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.9.0"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
