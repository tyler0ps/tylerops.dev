variable "aws_region" {
  default = "ap-southeast-1"
}

variable "instance_types" {
  description = "Spot instance type candidates (ARM64/Graviton)"
  default     = ["t4g.nano", "t4g.micro"]
}

variable "atlantis_domain" {
  description = "Public domain for Atlantis (used in --atlantis-url)"
  default     = "atlantis.tylerops.dev"
}

variable "repo_allowlist" {
  description = "GitHub repo allowlist pattern for Atlantis (e.g. github.com/myorg/myrepo)"
  default     = "github.com/tyler0ps/tylerops.dev"
}
