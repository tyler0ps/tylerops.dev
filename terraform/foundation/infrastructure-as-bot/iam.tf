locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid     = "ASGScale"
    actions = ["autoscaling:SetDesiredCapacity", "autoscaling:UpdateAutoScalingGroup", "autoscaling:StartInstanceRefresh"]
    resources = [
      "arn:aws:autoscaling:${local.region}:${local.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.authentik_asg_name}",
      "arn:aws:autoscaling:${local.region}:${local.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.nat_asg_name}",
      "arn:aws:autoscaling:${local.region}:${local.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.caddy_asg_name}",
      "arn:aws:autoscaling:${local.region}:${local.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.atlantis_asg_name}",
      "arn:aws:autoscaling:${local.region}:${local.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.plane_asg_name}",
    ]
  }

  statement {
    sid       = "ASGDescribe"
    actions   = ["autoscaling:DescribeAutoScalingGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "EC2Describe"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  statement {
    sid     = "SSMGetToken"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${local.region}:${local.account_id}:parameter${var.bot_token_ssm_path}",
    ]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "telegram-infra-bot-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "lambda" {
  name   = "telegram-infra-bot-lambda"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}
