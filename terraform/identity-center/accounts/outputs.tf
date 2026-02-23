output "prod_account_id" {
  description = "AWS account ID for the Prod account — pass this to sso/ as var.prod_account_id"
  value       = aws_organizations_account.prod.id
}

output "dev_account_id" {
  description = "AWS account ID for the Dev account — pass this to sso/ as var.dev_account_id"
  value       = aws_organizations_account.dev.id
}
