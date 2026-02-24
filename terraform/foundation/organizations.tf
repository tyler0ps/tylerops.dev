resource "aws_organizations_account" "prod" {
  name  = var.prod_account_name
  email = var.prod_account_email

  # Prevents accidental account closure via terraform destroy.
  # AWS account deletion takes 90 days and is irreversible from Terraform.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "dev" {
  name  = var.dev_account_name
  email = var.dev_account_email

  lifecycle {
    prevent_destroy = true
  }
}
