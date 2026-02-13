output "elastic_ip" {
  description = "Elastic IP address of Plane instance"
  value       = aws_eip.plane.public_ip
}

output "plane_url" {
  description = "URL to access Plane"
  value       = "https://${var.domain_name}"
}

output "ami_id" {
  description = "Custom Plane AMI ID used by Launch Template"
  value       = data.aws_ami.plane_custom.id
}

output "ebs_volume_id" {
  description = "EBS data volume ID (persistent)"
  value       = aws_ebs_volume.plane_data.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.plane.name
}

output "launch_template_id" {
  description = "Launch Template ID used by ASG"
  value       = aws_launch_template.plane.id
}

output "manual_start_command" {
  description = "Command to manually scale up Plane instance"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.plane.name} --desired-capacity 1 --region ${var.aws_region}"
}

output "manual_stop_command" {
  description = "Command to manually scale down Plane instance"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.plane.name} --desired-capacity 0 --region ${var.aws_region}"
}

output "instance_refresh_command" {
  description = "Command to force redeploy instance (instance refresh)"
  value       = "aws autoscaling start-instance-refresh --auto-scaling-group-name ${aws_autoscaling_group.plane.name} --preferences '{\"MinHealthyPercentage\": 0}' --region ${var.aws_region}"
}

output "ssm_command" {
  description = "SSM Session Manager command to connect to the instance"
  value       = "aws ssm start-session --target $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.plane.name} --region ${var.aws_region} --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text) --region ${var.aws_region}"
}
