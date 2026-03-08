# output "elastic_ip" {
#   description = "Elastic IP address of Authentik instance"
#   value       = aws_eip.authentik.public_ip
# }

output "authentik_url" {
  description = "URL to access Authentik"
  value       = "https://${var.domain_name}"
}

output "ami_id" {
  description = "Amazon Linux 2023 ARM64 AMI ID used by Launch Template"
  value       = data.aws_ami.al2023_arm64.id
}

output "ebs_volume_id" {
  description = "EBS data volume ID (persistent, prevent_destroy=true)"
  value       = aws_ebs_volume.authentik_data.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.authentik.name
}

output "manual_start_command" {
  description = "Command to manually scale up Authentik instance"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.authentik.name} --desired-capacity 1 --region ${var.aws_region}"
}

output "manual_stop_command" {
  description = "Command to manually scale down Authentik instance"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.authentik.name} --desired-capacity 0 --region ${var.aws_region}"
}

output "ssm_command" {
  description = "SSM Session Manager command to connect to the instance"
  value       = "aws ssm start-session --target $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.authentik.name} --region ${var.aws_region} --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text) --region ${var.aws_region}"
}
