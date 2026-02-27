# TODO: FIX. THIS IS NOT WORKING YET.
locals {
  terraform_deploy_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = var.github_actions_role_arn }
        Action    = "sts:AssumeRole"
      },
      {
        # Allow platform_admin SSO role from management account (suffix is dynamic)
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.management_account_id}:root" }
        Action    = "sts:AssumeRole"
        Condition = {
          ArnLike = {
            "aws:PrincipalArn" = "arn:aws:iam::${var.management_account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_*"
          }
        }
      }
    ]
  })
}

# --- PROD ACCOUNT ---

resource "aws_iam_role" "terraform_deploy_prod" {
  provider = aws.prod

  name               = "TerraformDeployRole"
  description        = "Assumed by GitHub Actions (management account) to deploy resources in prod"
  assume_role_policy = local.terraform_deploy_trust_policy
}

resource "aws_iam_role_policy_attachment" "terraform_deploy_prod" {
  provider = aws.prod

  role       = aws_iam_role.terraform_deploy_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- DEV ACCOUNT ---

resource "aws_iam_role" "terraform_deploy_dev" {
  provider = aws.dev

  name               = "TerraformDeployRole"
  description        = "Assumed by GitHub Actions (management account) to deploy resources in dev"
  assume_role_policy = local.terraform_deploy_trust_policy
}

resource "aws_iam_role_policy_attachment" "terraform_deploy_dev" {
  provider = aws.dev

  role       = aws_iam_role.terraform_deploy_dev.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
