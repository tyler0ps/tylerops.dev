variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Domain name for Plane EE"
  type        = string
  default     = "plane.tylerops.dev"
}

variable "instance_type" {
  description = "EC2 instance type (primary, used in launch template)"
  type        = string
  default     = "t4g.large" # ARM, 2 vCPU, 8GB RAM
}

variable "instance_types" {
  description = "List of instance types to try (in order) when capacity is unavailable"
  type        = list(string)
  default = [
    # "t4g.small", 
    "t4g.medium", # Graviton2, 2 vCPU, 4GB
    "t4g.large",  # Graviton2, 2 vCPU, 8GB
    # "m6g.medium", # Graviton2, 1 vCPU, 4GB
    # "m6g.large",  # Graviton2, 2 vCPU, 8GB
    # "m7g.medium", # Graviton3, 1 vCPU, 4GB
    # "m7g.large",  # Graviton3, 2 vCPU, 8GB
  ]
}

variable "ebs_size" {
  description = "EBS data volume size in GB"
  type        = number
  default     = 30
}

variable "telegram_bot_token" {
  description = "Telegram bot token from BotFather"
  type        = string
  sensitive   = true
  default     = "placeholder"
}

variable "telegram_chat_id" {
  description = "Allowed Telegram chat ID"
  type        = string
  default     = "placeholder"
}
