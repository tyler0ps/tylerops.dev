data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "random_password" "webhook_secret" {
  length  = 32
  special = false
}

resource "random_password" "url_path_secret" {
  length  = 32
  special = false
}
