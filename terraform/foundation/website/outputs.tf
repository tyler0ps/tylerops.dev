output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.site.id
}

output "website_url" {
  description = "Website URL"
  value       = "https://${var.domain_name}"
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.site.arn
}

output "route53_nameservers" {
  description = "Route53 nameservers - configure these in Dynadot"
  value       = aws_route53_zone.main.name_servers
}
