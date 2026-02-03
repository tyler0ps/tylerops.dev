output "elastic_ip" {
  description = "Elastic IP address of Plane instance"
  value       = aws_eip.plane.public_ip
}

output "plane_url" {
  description = "URL to access Plane"
  value       = "https://${var.domain_name}"
}

output "ssm_command" {
  description = "SSM Session Manager command to connect to the instance"
  value       = length(data.aws_instances.plane_managed.ids) > 0 ? "aws ssm start-session --target ${data.aws_instances.plane_managed.ids[0]} --region ${var.aws_region}" : "No instance running (use Lambda to start)"
}

output "instance_id" {
  description = "EC2 instance ID (Lambda-managed)"
  value       = length(data.aws_instances.plane_managed.ids) > 0 ? data.aws_instances.plane_managed.ids[0] : "No instance running"
}

output "ami_id" {
  description = "Custom Plane AMI ID used by Launch Template"
  value       = data.aws_ami.plane_custom.id
}

output "custom_ami_id" {
  description = "Custom Plane AMI ID"
  value       = try(data.aws_ami.plane_custom.id, "No custom AMI found")
}

# =============================================================================
# Lambda + EventBridge Outputs
# =============================================================================

output "lambda_function_name" {
  description = "Lambda function name for manual invocation"
  value       = aws_lambda_function.plane_manager.function_name
}

output "launch_template_id" {
  description = "Launch Template ID used by Lambda"
  value       = aws_launch_template.plane.id
}

output "ebs_volume_id" {
  description = "EBS data volume ID (persistent)"
  value       = aws_ebs_volume.plane_data.id
}

output "manual_start_command" {
  description = "Command to manually start Plane instance"
  value       = <<-EOT
    aws lambda invoke \
      --function-name ${aws_lambda_function.plane_manager.function_name} \
      --payload '{"action": "schedule_start"}' \
      --cli-binary-format raw-in-base64-out \
      response.json && cat response.json
  EOT
}

output "manual_stop_command" {
  description = "Command to manually stop Plane instance"
  value       = <<-EOT
    aws lambda invoke \
      --function-name ${aws_lambda_function.plane_manager.function_name} \
      --payload '{"action": "schedule_stop"}' \
      --cli-binary-format raw-in-base64-out \
      response.json && cat response.json
  EOT
}
