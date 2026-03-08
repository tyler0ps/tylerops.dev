variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Public domain name for Plane"
  type        = string
  default     = "capitalplace.tylerops.dev"
}

variable "instance_type" {
  description = "EC2 instance type (primary, used in launch template)"
  type        = string
  default     = "t4g.micro"
  # default     = "c8g.large"
}

variable "instance_types" {
  description = "List of instance types for spot allocation fallback"
  type        = list(string)
  default = [
    "t4g.micro",
    # "c8g.large",
    # "t4g.small",
    # "t4g.medium",
    # "c6g.medium",
    # "c7g.medium",
  ]
}
