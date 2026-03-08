terraform {
  backend "s3" {
    bucket       = "generic-gha-terraform-state"
    key          = "plane/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
