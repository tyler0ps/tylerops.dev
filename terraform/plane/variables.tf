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
  default     = "t4g.micro" # ARM, 2 vCPU, 4GB RAM
}

variable "instance_types" {
  description = "List of instance types to try (in order) when capacity is unavailable"
  type        = list(string)
  default = [
    "t4g.micro",
    # "t4g.small",
    # "t4g.medium",
    # "m6g.medium",
    # "m7g.medium",
    # "t4g.large",
    # "c6g.large",
  ]
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
