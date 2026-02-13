# =============================================================================
# Custom AMI for Plane EE (pre-installed Docker, Compose, Plane EE)
# =============================================================================

data "aws_ami" "plane_ee_custom" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["plane-ee-ami-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
