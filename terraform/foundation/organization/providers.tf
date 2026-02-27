terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Management account — SSO admin, Identity Store, Organizations
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "foundation"
      ManagedBy = "terraform"
    }
  }
}

# Prod account — OrganizationAccountAccessRole is auto-created by AWS Organizations
provider "aws" {
  alias  = "prod"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Project   = "foundation"
      ManagedBy = "terraform"
    }
  }
}

# Dev account
provider "aws" {
  alias  = "dev"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.dev_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Project   = "foundation"
      ManagedBy = "terraform"
    }
  }
}
