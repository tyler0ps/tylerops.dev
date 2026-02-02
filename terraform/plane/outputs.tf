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
  value       = "aws ssm start-session --target ${aws_instance.plane.id} --region ${var.aws_region}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.plane.id
}
