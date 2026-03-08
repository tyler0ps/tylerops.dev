output "nat_manual_scale_commands" {
  description = "Manual AWS CLI commands to scale NAT ASG up/down on demand"
  value       = <<-EOT
    # Scale DOWN (stop NAT — no outbound internet from private subnets):
    aws autoscaling set-desired-capacity \
      --auto-scaling-group-name ${module.nat.name} \
      --desired-capacity 0 \
      --no-honor-cooldown

    # Scale UP (restart NAT):
    aws autoscaling set-desired-capacity \
      --auto-scaling-group-name ${module.nat.name} \
      --desired-capacity 1 \
      --no-honor-cooldown
  EOT
}

output "vpc_id" {
  description = "Management VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Management public subnet ID (ap-southeast-1a)"
  value       = aws_subnet.public.id
}

output "vpc_cidr" {
  description = "Management VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes (az-a, az-b)"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "internal_zone_id" {
  description = "Private Route53 hosted zone ID for tylerops.internal"
  value       = aws_route53_zone.internal.zone_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (az-a, az-b)"
  value       = [aws_subnet.public.id, aws_subnet.public_b.id]
}

output "pod_subnet_ids_by_az" {
  description = "Pod subnet IDs by AZ - secondary CIDR 100.64.0.0/16 for VPC CNI custom networking"
  value = {
    "${var.aws_region}a" = aws_subnet.pods_a.id
    "${var.aws_region}b" = aws_subnet.pods_b.id
  }
}
