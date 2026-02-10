output "plane_public_ip" {
  description = "Plane EC2 public IP"
  value       = aws_eip.plane.public_ip
}

output "plane_url" {
  description = "Plane URL"
  value       = "https://${var.domain_name}"
}

output "plane_asg_name" {
  description = "Plane Auto Scaling Group name"
  value       = aws_autoscaling_group.plane.name
}

output "plane_launch_template_id" {
  description = "Plane Launch Template ID"
  value       = aws_launch_template.plane.id
}

output "data_instance_id" {
  description = "Data EC2 instance ID"
  value       = module.data.instance_id
}

output "db_dns_name" {
  description = "PostgreSQL internal DNS name"
  value       = module.data.db_dns_name
}

output "redis_dns_name" {
  description = "Redis internal DNS name"
  value       = module.data.redis_dns_name
}

output "mq_dns_name" {
  description = "RabbitMQ internal DNS name"
  value       = module.data.mq_dns_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for uploads"
  value       = aws_s3_bucket.uploads.bucket
}

output "ssm_connect_plane" {
  description = "SSM command to connect to Plane instance (get instance ID first)"
  value       = <<-EOT
# Get current instance ID from ASG:
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.plane.name} --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

# Then connect:
aws ssm start-session --target $INSTANCE_ID
EOT
}

output "ssm_connect_data" {
  description = "SSM command to connect to Data instance"
  value       = "aws ssm start-session --target ${module.data.instance_id}"
}

output "ssh_connect_plane" {
  description = "SSH command using EC2 Instance Connect"
  value       = <<-EOT
# EIP is always the same, just SSH directly:
ssh ec2-user@${aws_eip.plane.public_ip}

# Or using EC2 Instance Connect:
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.plane.name} --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)
aws ec2-instance-connect ssh --instance-id $INSTANCE_ID --os-user ec2-user
EOT
}

output "plane_s3_access_key" {
  description = "S3 access key for Plane"
  value       = aws_iam_access_key.plane_s3.id
  sensitive   = true
}

output "plane_s3_secret_key" {
  description = "S3 secret key for Plane"
  value       = aws_iam_access_key.plane_s3.secret
  sensitive   = true
}

output "plane_s3_endpoint" {
  description = "S3 endpoint URL for Plane"
  value       = "https://s3.${var.aws_region}.amazonaws.com"
}
