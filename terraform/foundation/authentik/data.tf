# =============================================================================
# Remote state references
# =============================================================================

# Networking — VPC and subnets from foundation/networking
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "generic-gha-terraform-state"
    key    = "foundation/networking/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

# Amazon Linux 2023 ARM64 (Graviton)
data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Route53 hosted zone (managed in management account)
data "aws_route53_zone" "main" {
  name = "tylerops.dev"
}
