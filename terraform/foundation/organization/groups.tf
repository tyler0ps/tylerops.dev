resource "aws_identitystore_group" "platform_admin" {
  identity_store_id = local.identity_store_id
  display_name      = "platform-admin"
  description       = "Platform administrators with full access across all accounts"
}

resource "aws_identitystore_group" "developer" {
  identity_store_id = local.identity_store_id
  display_name      = "developer"
  description       = "Developers with PowerUser access in dev, ReadOnly access in prod"
}

resource "aws_identitystore_group" "readonly" {
  identity_store_id = local.identity_store_id
  display_name      = "readonly"
  description       = "Read-only access in prod and dev accounts"
}
