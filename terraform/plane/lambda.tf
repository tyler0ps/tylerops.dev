# =============================================================================
# Lambda Function for Plane Instance Management
# =============================================================================

# Package Lambda code
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "plane_manager" {
  function_name = "plane-instance-manager"
  description   = "Manages Plane EC2 spot instance lifecycle"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 300 # 5 minutes (instance creation can take time)
  memory_size      = 128

  role = aws_iam_role.lambda.arn

  environment {
    variables = {
      LAUNCH_TEMPLATE_ID = aws_launch_template.plane.id
      EBS_VOLUME_ID      = aws_ebs_volume.plane_data.id
      EIP_ALLOCATION_ID  = aws_eip.plane.id
      SUBNET_ID          = aws_subnet.public.id
    }
  }

  tags = {
    Name = "plane-instance-manager"
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/plane-instance-manager"
  retention_in_days = 7

  tags = {
    Name = "plane-lambda-logs"
  }
}

# Lambda permission for EventBridge (schedule start)
resource "aws_lambda_permission" "eventbridge_start" {
  statement_id  = "AllowEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.plane_manager.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_start.arn
}

# Lambda permission for EventBridge (schedule stop)
resource "aws_lambda_permission" "eventbridge_stop" {
  statement_id  = "AllowEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.plane_manager.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_stop.arn
}

# Lambda permission for EventBridge (spot interruption)
resource "aws_lambda_permission" "eventbridge_spot" {
  statement_id  = "AllowEventBridgeSpotInterruption"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.plane_manager.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.spot_interruption.arn
}
