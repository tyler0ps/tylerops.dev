packer {
  required_plugins {
    amazon = {
      version = ">= 1.8.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  default = "ap-southeast-1"
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
}

data "amazon-ami" "al2023_arm64" {
  region      = var.aws_region
  owners      = ["amazon"]
  most_recent = true

  filters = {
    name                = "al2023-ami-*-arm64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
}

source "amazon-ebs" "authentik" {
  region        = var.aws_region
  source_ami    = data.amazon-ami.al2023_arm64.id
  instance_type = "c8g.large"
  ssh_username  = "ec2-user"

  ami_name        = "authentik-${local.timestamp}"
  ami_description = "Authentik IdP AL2023 ARM64"

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = "authentik-${local.timestamp}"
    ManagedBy = "packer"
    Service   = "authentik"
  }
}

build {
  name    = "authentik"
  sources = ["source.amazon-ebs.authentik"]

  provisioner "shell" {
    script = "${path.root}/scripts/install.sh"
  }
}
