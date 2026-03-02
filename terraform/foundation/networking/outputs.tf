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
