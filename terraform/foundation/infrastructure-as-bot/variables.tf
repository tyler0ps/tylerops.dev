variable "aws_region" {
  default = "ap-southeast-1"
}

variable "bot_token_ssm_path" {
  description = "SSM Parameter path for Telegram bot token (SecureString) — create manually before apply"
  default     = "/telegram-bot/token"
}

variable "allowed_chat_id" {
  description = "Telegram chat_id allowed to execute commands (get from @userinfobot)"
  type        = string
}

variable "authentik_asg_name" {
  default = "authentik-asg"
}

variable "nat_asg_name" {
  default = "management-nat"
}
