variable "aws_region" {
  description = "AWS region for main resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "tylerops.dev"
}

variable "site_bucket_name" {
  description = "S3 bucket name for static site"
  type        = string
  default     = "oceancloud-click-site"
}

variable "github_repo" {
  description = "GitHub repository (org/repo format)"
  type        = string
  default     = "tyler0ps/tylerops.dev"
}
