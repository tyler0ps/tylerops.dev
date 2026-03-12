output "external_dns_irsa_arn" {
  description = "ARN of IAM role for external-dns"
  value       = aws_iam_role.external_dns.arn
}

output "loki_irsa_arn" {
  description = "ARN of IAM role for Loki"
  value       = aws_iam_role.loki.arn
}

output "loki_s3_bucket" {
  description = "S3 bucket name for Loki log storage"
  value       = aws_s3_bucket.loki.bucket
}

output "envoy_nlb_dns_name" {
  description = "DNS name of the Envoy Gateway NLB"
  value       = aws_lb.envoy.dns_name
}

output "envoy_nlb_arn" {
  description = "DNS name of the Envoy Gateway NLB"
  value       = aws_lb.envoy.arn
}

# output "acm_certificate_arn" {
#   description = "ARN of the ACM wildcard certificate"
#   value       = aws_acm_certificate_validation.wildcard.certificate_arn
# }

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.region}"
}
