# =============================================================================
# EventBridge Rules for Plane Instance Scheduling
# =============================================================================

# Schedule: Start instance at 7 AM ICT (00:00 UTC) every day
resource "aws_cloudwatch_event_rule" "schedule_start" {
  name                = "plane-schedule-start"
  description         = "Start Plane instance at 7 AM ICT every day"
  schedule_expression = "cron(0 0 ? * * *)"

  tags = {
    Name = "plane-schedule-start"
  }
}

resource "aws_cloudwatch_event_target" "schedule_start" {
  rule      = aws_cloudwatch_event_rule.schedule_start.name
  target_id = "plane-lambda-start"
  arn       = aws_lambda_function.plane_manager.arn

  input = jsonencode({
    action = "schedule_start"
  })
}

# Schedule: Stop instance at 10 PM ICT (15:00 UTC) every day
resource "aws_cloudwatch_event_rule" "schedule_stop" {
  name                = "plane-schedule-stop"
  description         = "Stop Plane instance at 10 PM ICT every day"
  schedule_expression = "cron(0 15 ? * * *)"

  tags = {
    Name = "plane-schedule-stop"
  }
}

resource "aws_cloudwatch_event_target" "schedule_stop" {
  rule      = aws_cloudwatch_event_rule.schedule_stop.name
  target_id = "plane-lambda-stop"
  arn       = aws_lambda_function.plane_manager.arn

  input = jsonencode({
    action = "schedule_stop"
  })
}

# =============================================================================
# EventBridge Rule for Spot Instance Interruption Warning
# =============================================================================

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "plane-spot-interruption"
  description = "Handle EC2 Spot Instance Interruption Warning for Plane"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = {
    Name = "plane-spot-interruption"
  }
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "plane-lambda-spot"
  arn       = aws_lambda_function.plane_manager.arn
}
