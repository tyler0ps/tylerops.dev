# =============================================================================
# Lambda Function for Plane EE Graceful Shutdown (ASG Lifecycle Hook)
# =============================================================================

# Package Lambda code
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "plane_ee_manager" {
  function_name = "plane-ee-instance-manager"
  description   = "Handles graceful shutdown for Plane EE instance via ASG lifecycle hook"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 128

  role = aws_iam_role.lambda.arn

  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.plane_ee.name
    }
  }

  tags = {
    Name = "plane-ee-instance-manager"
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/plane-ee-instance-manager"
  retention_in_days = 7

  tags = {
    Name = "plane-ee-lambda-logs"
  }
}

# Lambda permission for EventBridge (lifecycle hook)
resource "aws_lambda_permission" "eventbridge_lifecycle" {
  statement_id  = "AllowEventBridgeLifecycle"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.plane_ee_manager.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lifecycle_terminating.arn
}

# =============================================================================
# ASG Lifecycle Hook for Termination
# =============================================================================

resource "aws_autoscaling_lifecycle_hook" "terminating" {
  name                   = "plane-ee-graceful-shutdown"
  autoscaling_group_name = aws_autoscaling_group.plane_ee.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 120
  default_result         = "ABANDON"
}
