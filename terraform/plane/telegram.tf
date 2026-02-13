# =============================================================================
# Telegram Bot for Plane ASG Control
# =============================================================================

# Webhook security: secret path + secret token header
resource "random_password" "webhook_path" {
  length  = 32
  special = false
}

resource "random_password" "webhook_secret" {
  length  = 64
  special = false
}

resource "aws_ssm_parameter" "telegram_webhook_secret" {
  name  = "/plane/telegram/webhook-secret"
  type  = "SecureString"
  value = random_password.webhook_secret.result

  lifecycle {
    ignore_changes = [value]
  }
}

# SSM Parameters (set values manually or via TF vars)
resource "aws_ssm_parameter" "telegram_bot_token" {
  name  = "/plane/telegram/bot-token"
  type  = "SecureString"
  value = var.telegram_bot_token

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "telegram_chat_id" {
  name  = "/plane/telegram/chat-id"
  type  = "String"
  value = var.telegram_chat_id

  lifecycle {
    ignore_changes = [value]
  }
}

# =============================================================================
# Lambda Function
# =============================================================================

data "archive_file" "telegram" {
  type        = "zip"
  source_dir  = "${path.module}/telegram"
  output_path = "${path.module}/telegram.zip"
}

resource "aws_lambda_function" "telegram_bot" {
  function_name = "plane-telegram-bot"
  description   = "Telegram bot for Plane ASG control"

  filename         = data.archive_file.telegram.output_path
  source_code_hash = data.archive_file.telegram.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128

  role = aws_iam_role.telegram_lambda.arn

  environment {
    variables = {
      ASG_NAME                  = aws_autoscaling_group.plane.name
      SSM_BOT_TOKEN_PARAM       = aws_ssm_parameter.telegram_bot_token.name
      SSM_CHAT_ID_PARAM         = aws_ssm_parameter.telegram_chat_id.name
      SSM_WEBHOOK_SECRET_PARAM  = aws_ssm_parameter.telegram_webhook_secret.name
      EIP_ADDRESS               = aws_eip.plane.public_ip
      LAMBDA_LOG_GROUP          = aws_cloudwatch_log_group.telegram_lambda.name
    }
  }

  tags = {
    Name = "plane-telegram-bot"
  }
}

resource "aws_cloudwatch_log_group" "telegram_lambda" {
  name              = "/aws/lambda/plane-telegram-bot"
  retention_in_days = 7

  tags = {
    Name = "plane-telegram-bot-logs"
  }
}

# =============================================================================
# API Gateway HTTP API (replaces Lambda Function URL)
# =============================================================================

resource "aws_apigatewayv2_api" "telegram" {
  name          = "plane-telegram-bot"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "telegram" {
  api_id                 = aws_apigatewayv2_api.telegram.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.telegram_bot.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "telegram" {
  api_id    = aws_apigatewayv2_api.telegram.id
  route_key = "POST /${random_password.webhook_path.result}"
  target    = "integrations/${aws_apigatewayv2_integration.telegram.id}"
}

resource "aws_apigatewayv2_stage" "telegram" {
  api_id      = aws_apigatewayv2_api.telegram.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_telegram" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telegram_bot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.telegram.execution_arn}/*/*"
}

# =============================================================================
# IAM Role for Telegram Lambda
# =============================================================================

resource "aws_iam_role" "telegram_lambda" {
  name = "plane-telegram-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "telegram_lambda_basic" {
  role       = aws_iam_role.telegram_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "telegram_lambda_permissions" {
  name = "plane-telegram-lambda-permissions"
  role = aws_iam_role.telegram_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ASGControl"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:StartInstanceRefresh"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.telegram_lambda.arn}:*"
      },
      {
        Sid    = "SSMGetParams"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          aws_ssm_parameter.telegram_bot_token.arn,
          aws_ssm_parameter.telegram_chat_id.arn,
          aws_ssm_parameter.telegram_webhook_secret.arn
        ]
      }
    ]
  })
}
