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

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = var.use_custom_ami ? data.aws_ami.plane_custom.id : data.aws_ami.amazon_linux_2023.id
}

output "custom_ami_id" {
  description = "Custom Plane AMI ID (if available)"
  value       = try(data.aws_ami.plane_custom.id, "No custom AMI found")
}
