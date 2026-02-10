output "instance_id" {
  description = "Data EC2 instance ID"
  value       = aws_instance.data.id
}

output "private_ip" {
  description = "Data instance private IP address"
  value       = aws_instance.data.private_ip
}

# PostgreSQL outputs
output "db_dns_name" {
  description = "PostgreSQL DNS name"
  value       = aws_route53_record.db.fqdn
}

output "db_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.db_user}:${var.db_password}@${aws_route53_record.db.fqdn}:5432/${var.db_name}"
  sensitive   = true
}

# Redis outputs
output "redis_dns_name" {
  description = "Redis DNS name"
  value       = aws_route53_record.redis.fqdn
}

output "redis_url" {
  description = "Redis connection URL"
  value       = "redis://${aws_route53_record.redis.fqdn}:6379/"
}

# RabbitMQ outputs
output "mq_dns_name" {
  description = "RabbitMQ DNS name"
  value       = aws_route53_record.mq.fqdn
}

output "mq_amqp_url" {
  description = "RabbitMQ AMQP connection URL"
  value       = "amqp://${var.mq_user}:${var.mq_password}@${aws_route53_record.mq.fqdn}:5672/${var.mq_vhost}"
  sensitive   = true
}

# Security group
output "security_group_id" {
  description = "Data instance security group ID"
  value       = aws_security_group.data.id
}

# Private hosted zone
output "private_zone_id" {
  description = "Private hosted zone ID"
  value       = aws_route53_zone.private.zone_id
}
