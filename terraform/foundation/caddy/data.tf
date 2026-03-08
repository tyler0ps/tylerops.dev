data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "generic-gha-terraform-state"
    key    = "foundation/networking/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "aws_ami" "caddy" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["caddy-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_route53_zone" "main" {
  name         = "tylerops.dev"
  private_zone = false
}
