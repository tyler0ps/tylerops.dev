# =============================================================================
# EventBridge Rule for ASG Lifecycle Hook (Graceful Shutdown)
# Triggers Lambda when ASG initiates instance termination
# =============================================================================

resource "aws_cloudwatch_event_rule" "lifecycle_terminating" {
  name        = "plane-ee-lifecycle-terminating"
  description = "Trigger graceful shutdown when ASG terminates Plane EE instance"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance-terminate Lifecycle Action"]
    detail = {
      AutoScalingGroupName = [aws_autoscaling_group.plane_ee.name]
    }
  })

  tags = {
    Name = "plane-ee-lifecycle-terminating"
  }
}

resource "aws_cloudwatch_event_target" "lifecycle_terminating" {
  rule      = aws_cloudwatch_event_rule.lifecycle_terminating.name
  target_id = "plane-ee-lambda-graceful-shutdown"
  arn       = aws_lambda_function.plane_ee_manager.arn
}
