variable "aws_region" {
  default = "ap-southeast-1"
}

variable "instance_types" {
  description = "Spot instance type candidates (ARM64/Graviton)"
  default     = ["t4g.nano", "t4g.micro"]
}

variable "atlantis_domain" {
  description = "Public domain for Atlantis"
  default     = "atlantis.tylerops.dev"
}

variable "authentik_domain" {
  description = "Authentik domain for forward auth"
  default     = "auth.tylerops.dev"
}

variable "acme_email" {
  description = "Email for Let's Encrypt ACME account registration"
  default     = "me@tylerops.dev"
}

variable "plane_domain" {
  description = "Public domain for Plane"
  default     = "capitalplace.tylerops.dev"
}
