output "elastic_ip" {
  description = "Elastic IP address of Vikunja instance"
  value       = aws_eip.vikunja.public_ip
}

output "vikunja_url" {
  description = "URL to access Vikunja"
  value       = "https://${var.domain_name}"
}

output "ssm_command" {
  description = "SSM Session Manager command to connect to the instance"
  value       = "aws ssm start-session --target ${aws_instance.vikunja.id} --region ${var.aws_region}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.vikunja.id
}
