# =============================================================================
# Custom AMI for Authentik (pre-installed Docker, Compose, Caddy, Authentik)
# =============================================================================

data "aws_ami" "authentik_custom" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["authentik-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}