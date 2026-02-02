variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Domain name for Vikunja"
  type        = string
  default     = "task.tylerops.dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "vikunja_jwt_secret" {
  description = "JWT secret for Vikunja authentication"
  type        = string
  sensitive   = true
}
