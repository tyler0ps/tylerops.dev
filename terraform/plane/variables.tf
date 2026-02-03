variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Domain name for Plane"
  type        = string
  default     = "capitalplace.tylerops.dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.medium" # ARM, 2 vCPU, 4GB RAM
}

variable "use_custom_ami" {
  description = "Use custom Plane AMI instead of base Amazon Linux"
  type        = bool
  default     = false
}

