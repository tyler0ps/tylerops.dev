variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Domain name for Authentik"
  type        = string
  default     = "auth.tylerops.dev"
}

variable "instance_type" {
  description = "EC2 instance type (primary, used in launch template)"
  type        = string
  # default     = "c8g.medium"
  default     = "t4g.micro"
}

variable "instance_types" {
  description = "List of instance types for spot allocation fallback"
  type        = list(string)
  default = [
    "t4g.micro",
    # "t4g.medium",
    # "c6g.medium",
    # "c8g.medium",
    # "c6g.medium",
    # "c7g.medium",
    # "t4g.medium",
    # "m6g.medium",
  ]
}
