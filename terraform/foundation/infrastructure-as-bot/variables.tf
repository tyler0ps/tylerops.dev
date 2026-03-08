variable "aws_region" {
  default = "ap-southeast-1"
}

variable "bot_token_ssm_path" {
  description = "SSM Parameter path for Telegram bot token (SecureString) — create manually before apply"
  default     = "/telegram-bot/token"
}

variable "authentik_asg_name" {
  default = "authentik-asg"
}

variable "nat_asg_name" {
  default = "management-nat"
}

variable "caddy_asg_name" {
  default = "caddy-asg"
}

variable "atlantis_asg_name" {
  default = "atlantis-asg"
}

variable "plane_asg_name" {
  default = "plane-asg"
}
