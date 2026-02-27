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
