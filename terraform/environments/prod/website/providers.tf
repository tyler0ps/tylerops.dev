terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Prod account — S3, CloudFront, ACM cert, IAM
provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::970290366693:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Project     = "tylerops-dev"
      ManagedBy   = "terraform"
      Environment = "production"
    }
  }
}

# Prod account us-east-1 — ACM cert (required for CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::970290366693:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Project     = "tylerops-dev"
      ManagedBy   = "terraform"
      Environment = "production"
    }
  }
}

# Management account — Route53 hosted zone (centralized DNS)
provider "aws" {
  alias  = "management"
  region = var.aws_region
}
