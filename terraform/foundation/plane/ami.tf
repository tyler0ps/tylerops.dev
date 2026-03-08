# =============================================================================
# Custom AMI for Plane (pre-installed Docker, Compose, Plane)
# =============================================================================

data "aws_ami" "plane_custom" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["plane-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
