terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider - ap-southeast-1 (Singapore)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "oceancloud-click"
      ManagedBy   = "terraform"
      Environment = "production"
    }
  }
}

# Provider for ACM certificate (must be us-east-1 for CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "oceancloud-click"
      ManagedBy   = "terraform"
      Environment = "production"
    }
  }
}
