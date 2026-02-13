# =============================================================================
# Data Sources - Reuse plane VPC infrastructure
# =============================================================================

data "aws_vpc" "plane" {
  filter {
    name   = "tag:Name"
    values = ["plane-vpc"]
  }
}

data "aws_subnet" "plane_public" {
  filter {
    name   = "tag:Name"
    values = ["plane-public-subnet"]
  }
}
