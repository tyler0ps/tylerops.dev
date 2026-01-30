# Backend configuration for Karpenter experiment
# State stored separately from other environments
terraform {
  backend "s3" {
    bucket       = "generic-gha-terraform-state"
    key          = "experiments/karpenter-experiment/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
