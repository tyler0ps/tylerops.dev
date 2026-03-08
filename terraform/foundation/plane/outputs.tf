output "plane_url" {
  description = "URL to access Plane"
  value       = "https://${var.domain_name}"
}

output "ebs_volume_id" {
  description = "EBS data volume ID (persistent, prevent_destroy=true)"
  value       = aws_ebs_volume.plane_data.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.plane.name
}

output "manual_start_command" {
  description = "Command to manually scale up Plane instance"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.plane.name} --desired-capacity 1 --region ${var.aws_region}"
}

output "manual_stop_command" {
  description = "Command to manually scale down Plane instance"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.plane.name} --desired-capacity 0 --region ${var.aws_region}"
}

output "ssm_command" {
  description = "SSM Session Manager command to connect to the instance"
  value       = "aws ssm start-session --target $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.plane.name} --region ${var.aws_region} --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text) --region ${var.aws_region}"
}
