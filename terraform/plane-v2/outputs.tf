output "plane_public_ip" {
  description = "Plane EC2 public IP"
  value       = aws_eip.plane.public_ip
}

output "plane_url" {
  description = "Plane URL"
  value       = "https://${var.domain_name}"
}

output "plane_instance_id" {
  description = "Plane EC2 instance ID"
  value       = aws_instance.plane.id
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
  description = "SSM command to connect to Plane instance"
  value       = "aws ssm start-session --target ${aws_instance.plane.id}"
}

output "ssm_connect_data" {
  description = "SSM command to connect to Data instance"
  value       = "aws ssm start-session --target ${module.data.instance_id}"
}

output "ssh_connect_plane" {
  description = "SSH command using EC2 Instance Connect"
  value       = <<-EOT
# Option 1: Using EC2 Instance Connect CLI (recommended)
aws ec2-instance-connect ssh --instance-id ${aws_instance.plane.id} --os-user ec2-user

# Option 2: Manual method (send key then SSH)
aws ec2-instance-connect send-ssh-public-key \
  --instance-id ${aws_instance.plane.id} \
  --instance-os-user ec2-user \
  --ssh-public-key file://~/.ssh/id_rsa.pub \
  --availability-zone ${var.aws_region}a && \
ssh -o StrictHostKeyChecking=no ec2-user@${aws_eip.plane.public_ip}
EOT
}
