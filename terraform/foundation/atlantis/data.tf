data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "generic-gha-terraform-state"
    key    = "foundation/networking/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "terraform_remote_state" "caddy" {
  backend = "s3"
  config = {
    bucket = "generic-gha-terraform-state"
    key    = "foundation/caddy/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "aws_ami" "atlantis" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["atlantis-*"]
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
