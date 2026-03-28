output "asg_name" {
  value = aws_autoscaling_group.playground.name
}

output "ssm_command" {
  description = "Connect to Playground via SSM Session Manager"
  value       = "aws ssm start-session --target $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names playground-asg --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text --region ap-southeast-1)"
}

output "manual_start_command" {
  value = "aws autoscaling set-desired-capacity --auto-scaling-group-name playground-asg --desired-capacity 1 --region ap-southeast-1"
}

output "manual_stop_command" {
  value = "aws autoscaling set-desired-capacity --auto-scaling-group-name playground-asg --desired-capacity 0 --region ap-southeast-1"
}

output "ami_details" {
  value = data.aws_ami.ubuntu.name
}