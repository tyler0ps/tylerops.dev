output "asg_name" {
  value = aws_autoscaling_group.atlantis.name
}

output "ssm_command" {
  description = "Connect to Atlantis via SSM Session Manager"
  value       = "aws ssm start-session --target $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names atlantis-asg --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text --region ap-southeast-1)"
}

output "manual_start_command" {
  value = "aws autoscaling set-desired-capacity --auto-scaling-group-name atlantis-asg --desired-capacity 1 --region ap-southeast-1"
}

output "manual_stop_command" {
  value = "aws autoscaling set-desired-capacity --auto-scaling-group-name atlantis-asg --desired-capacity 0 --region ap-southeast-1"
}
