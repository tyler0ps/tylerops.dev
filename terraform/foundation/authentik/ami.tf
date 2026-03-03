# =============================================================================
# Custom AMI for Authentik (pre-installed Docker, Compose, Caddy, Authentik)
# =============================================================================

data "aws_ami" "authentik_custom" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    # values = ["authentik-ami-*"] # authentik only, ami-0f9fcc57dd29c08b2
    values = ["authentik-plane-*"] # ami-0821a01b29e06dc9b
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}