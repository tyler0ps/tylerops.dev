variable "cluster_source" {
  description = "Which cluster remote state to read: eks-foundation or eks-cilium"
  type        = string
  default     = "eks-cilium"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "tags" {
  description = "Additional tags to merge with default tags"
  type        = map(string)
  default     = {}
}
