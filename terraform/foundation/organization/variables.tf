variable "aws_region" {
  description = "AWS region for provider configuration"
  type        = string
  default     = "ap-southeast-1"
}

variable "management_account_id" {
  description = "Management AWS account ID"
  type        = string
  default     = "382027875658"
}

variable "prod_account_id" {
  description = "Prod AWS account ID"
  type        = string
  default     = "970290366693"
}

variable "dev_account_id" {
  description = "Dev AWS account ID"
  type        = string
  default     = "897391589441"
}

variable "prod_account_name" {
  description = "Display name for the Prod AWS account"
  type        = string
  default     = "prod"
}

variable "prod_account_email" {
  description = "Root email for the Prod AWS account"
  type        = string
  default     = "aws-prod@tylerops.dev"
}

variable "dev_account_name" {
  description = "Display name for the Dev AWS account"
  type        = string
  default     = "dev"
}

variable "dev_account_email" {
  description = "Root email for the Dev AWS account"
  type        = string
  default     = "aws-dev@tylerops.dev"
}

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role in management account"
  type        = string
  default     = "arn:aws:iam::382027875658:role/github-actions-oceancloud-click"
}
