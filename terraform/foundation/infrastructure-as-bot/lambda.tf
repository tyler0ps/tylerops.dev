data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "bot" {
  function_name    = "telegram-infra-bot"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      WEBHOOK_SECRET     = random_password.webhook_secret.result
      BOT_TOKEN_SSM_PATH = var.bot_token_ssm_path
      AUTHENTIK_ASG_NAME = var.authentik_asg_name
      NAT_ASG_NAME       = var.nat_asg_name
      CADDY_ASG_NAME     = var.caddy_asg_name
      ATLANTIS_ASG_NAME  = var.atlantis_asg_name
      PLANE_ASG_NAME     = var.plane_asg_name
      ALLOWED_CHAT_ID    = data.aws_ssm_parameter.allowed_chat_id.value
    }
  }
}
