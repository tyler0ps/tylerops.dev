terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

provider "kubernetes" {
  host                   = module.eks_cilium.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cilium.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", local.region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks_cilium.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cilium.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", local.region]
    }
  }
}

provider "kubectl" {
  host                   = module.eks_cilium.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cilium.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", local.region]
  }
}
