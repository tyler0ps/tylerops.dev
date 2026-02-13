output "elastic_ip" {
  description = "Elastic IP address of Plane EE instance"
  value       = aws_eip.plane_ee.public_ip
}

output "plane_url" {
  description = "URL to access Plane EE"
  value       = "https://${var.domain_name}"
}

output "ami_id" {
  description = "Custom Plane EE AMI ID used by Launch Template"
  value       = data.aws_ami.plane_ee_custom.id
}

output "ebs_volume_id" {
  description = "EBS data volume ID (persistent)"
  value       = aws_ebs_volume.plane_ee_data.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.plane_ee.name
}

output "launch_template_id" {
  description = "Launch Template ID used by ASG"
  value       = aws_launch_template.plane_ee.id
}

output "manual_start_command" {
  description = "Command to manually scale up Plane EE instance"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.plane_ee.name} --desired-capacity 1 --region ${var.aws_region}"
}

output "manual_stop_command" {
  description = "Command to manually scale down Plane EE instance"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.plane_ee.name} --desired-capacity 0 --region ${var.aws_region}"
}

output "instance_refresh_command" {
  description = "Command to force redeploy instance (instance refresh)"
  value       = "aws autoscaling start-instance-refresh --auto-scaling-group-name ${aws_autoscaling_group.plane_ee.name} --preferences '{\"MinHealthyPercentage\": 0}' --region ${var.aws_region}"
}

output "ssm_command" {
  description = "SSM Session Manager command to connect to the instance"
  value       = "aws ssm start-session --target $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.plane_ee.name} --region ${var.aws_region} --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text) --region ${var.aws_region}"
}

output "telegram_webhook_url" {
  description = "Telegram bot webhook URL (API Gateway with secret path)"
  value       = "${aws_apigatewayv2_stage.telegram.invoke_url}${random_password.webhook_path.result}"
  sensitive   = true
}

output "telegram_set_webhook_command" {
  description = "Command to register Telegram webhook with secret token"
  value       = <<-EOT
    curl -s -X POST 'https://api.telegram.org/bot'$(aws ssm get-parameter --name ${aws_ssm_parameter.telegram_bot_token.name} --with-decryption --query Parameter.Value --output text --region ${var.aws_region})'/setWebhook' \
      -d url=${aws_apigatewayv2_stage.telegram.invoke_url}${random_password.webhook_path.result} \
      -d secret_token=$(aws ssm get-parameter --name ${aws_ssm_parameter.telegram_webhook_secret.name} --with-decryption --query Parameter.Value --output text --region ${var.aws_region})
  EOT
  sensitive   = true
}
