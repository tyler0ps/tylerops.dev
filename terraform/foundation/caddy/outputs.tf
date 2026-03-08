output "atlantis_url" {
  description = "Atlantis public URL"
  value       = "https://${var.atlantis_domain}"
}

output "security_group_id" {
  description = "Caddy SG ID — referenced by Atlantis SG to allow inbound on port 4141"
  value       = aws_security_group.caddy.id
}

output "asg_name" {
  value = aws_autoscaling_group.caddy.name
}
