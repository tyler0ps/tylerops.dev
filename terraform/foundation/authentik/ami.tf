# =============================================================================
# Custom AMI for Authentik (pre-installed Docker, Compose, Caddy, Authentik)
# =============================================================================

data "aws_ami" "authentik_custom" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["authentik-ami-*"] # ami-0952223645eba851b
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
