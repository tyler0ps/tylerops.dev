output "prod_account_id" {
  description = "AWS account ID for the Prod account"
  value       = aws_organizations_account.prod.id
}

output "dev_account_id" {
  description = "AWS account ID for the Dev account"
  value       = aws_organizations_account.dev.id
}

output "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "Identity Store ID"
  value       = local.identity_store_id
}

output "group_ids" {
  description = "Map of group name to Identity Store group ID"
  value = {
    platform_admin = aws_identitystore_group.platform_admin.group_id
    developer      = aws_identitystore_group.developer.group_id
    readonly       = aws_identitystore_group.readonly.group_id
  }
}

output "permission_set_arns" {
  description = "Map of permission set name to ARN"
  value = {
    administrator_access = aws_ssoadmin_permission_set.administrator_access.arn
    power_user_access    = aws_ssoadmin_permission_set.power_user_access.arn
    read_only_access     = aws_ssoadmin_permission_set.read_only_access.arn
  }
}

output "terraform_deploy_role_arns" {
  description = "TerraformDeployRole ARNs — use these in environments/ provider assume_role blocks"
  value = {
    prod = aws_iam_role.terraform_deploy_prod.arn
    dev  = aws_iam_role.terraform_deploy_dev.arn
  }
}
