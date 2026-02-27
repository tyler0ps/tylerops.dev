# --- OWNER ---

resource "aws_identitystore_user" "tyler" {
  identity_store_id = local.identity_store_id

  user_name    = "tyler"
  display_name = "Tyler"

  name {
    given_name  = "Tyler"
    family_name = "Nong"
  }

  emails {
    value   = "me@tylerops.dev"
    type    = "work"
    primary = true
  }
}

resource "aws_identitystore_group_membership" "tyler_platform_admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.platform_admin.group_id
  member_id         = aws_identitystore_user.tyler.user_id
}

# --- TEST USERS ---


resource "aws_identitystore_user" "test_developer" {
  identity_store_id = local.identity_store_id

  user_name    = "test-developer"
  display_name = "Test Developer"

  name {
    given_name  = "Test"
    family_name = "Developer"
  }

  emails {
    value   = "test-developer@tylerops.dev"
    type    = "work"
    primary = true
  }
}

resource "aws_identitystore_group_membership" "test_developer_developer" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.developer.group_id
  member_id         = aws_identitystore_user.test_developer.user_id
}

resource "aws_identitystore_user" "test_readonly" {
  identity_store_id = local.identity_store_id

  user_name    = "test-readonly"
  display_name = "Test Readonly"

  name {
    given_name  = "Test"
    family_name = "Readonly"
  }

  emails {
    value   = "test-readonly@tylerops.dev"
    type    = "work"
    primary = true
  }
}

resource "aws_identitystore_group_membership" "test_readonly_readonly" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.readonly.group_id
  member_id         = aws_identitystore_user.test_readonly.user_id
}
