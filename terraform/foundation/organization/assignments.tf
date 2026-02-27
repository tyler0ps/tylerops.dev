locals {
  account_ids = {
    management = var.management_account_id
    prod       = var.prod_account_id
    dev        = var.dev_account_id
  }

  group_ids = {
    platform_admin = aws_identitystore_group.platform_admin.group_id
    developer      = aws_identitystore_group.developer.group_id
    readonly       = aws_identitystore_group.readonly.group_id
  }

  permission_set_arns = {
    AdministratorAccess = aws_ssoadmin_permission_set.administrator_access.arn
    PowerUserAccess     = aws_ssoadmin_permission_set.power_user_access.arn
    ReadOnlyAccess      = aws_ssoadmin_permission_set.read_only_access.arn
  }

  # Assignment matrix — add/remove entries here to change access
  # Key format: "<group>__<account>"
  assignments = {
    "platform_admin__management" = { group = "platform_admin", account = "management", ps = "AdministratorAccess" }
    "platform_admin__prod"       = { group = "platform_admin", account = "prod",       ps = "AdministratorAccess" }
    "platform_admin__dev"        = { group = "platform_admin", account = "dev",        ps = "AdministratorAccess" }
    "developer__prod"            = { group = "developer",      account = "prod",       ps = "ReadOnlyAccess" }
    "developer__dev"             = { group = "developer",      account = "dev",        ps = "PowerUserAccess" }
    "readonly__prod"             = { group = "readonly",       account = "prod",       ps = "ReadOnlyAccess" }
    "readonly__dev"              = { group = "readonly",       account = "dev",        ps = "ReadOnlyAccess" }
  }
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.assignments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = local.permission_set_arns[each.value.ps]

  principal_type = "GROUP"
  principal_id   = local.group_ids[each.value.group]

  target_type = "AWS_ACCOUNT"
  target_id   = local.account_ids[each.value.account]
}
