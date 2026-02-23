variable "aws_region" {
  description = "AWS region for provider configuration"
  type        = string
  default     = "ap-southeast-1"
}

variable "prod_account_name" {
  description = "Display name for the Prod AWS account"
  type        = string
  default     = "prod"
}

variable "prod_account_email" {
  description = "Unique root email for the Prod AWS account (e.g. aws+prod@yourdomain.com)"
  type        = string
  default     = "aws-prod@tylerops.dev"
}

variable "dev_account_name" {
  description = "Display name for the Dev AWS account"
  type        = string
  default     = "dev"
}

variable "dev_account_email" {
  description = "Unique root email for the Dev AWS account (e.g. aws+dev@yourdomain.com)"
  type        = string
  default     = "aws-dev@tylerops.dev"
}
