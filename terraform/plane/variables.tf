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
  description = "EC2 instance type (primary, used in launch template)"
  type        = string
  default     = "t4g.medium" # ARM, 2 vCPU, 4GB RAM
}

variable "instance_types" {
  description = "List of instance types to try (in order) when capacity is unavailable"
  type        = list(string)
  default = [
    "t4g.small",  # Graviton2, 1 vCPU, 2GB
    "t4g.medium", # Graviton2, 2 vCPU, 4GB
    "m6g.medium", # Graviton2, 1 vCPU, 4GB
    "m7g.medium", # Graviton3, 1 vCPU, 4GB
    "t4g.large",  # Graviton2, 2 vCPU, 8GB
    "c6g.large",  # Graviton2, 2 vCPU, 4GB
  ]
}
