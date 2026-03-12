# ============================================================
# EXTERNAL-DNS — IRSA
# ============================================================

locals {
  external_dns_namespace       = "external-dns"
  external_dns_service_account = "external-dns"
}

resource "aws_iam_policy" "external_dns_route53" {
  name        = "${local.cluster_name}-external-dns-route53"
  description = "Allow external-dns to manage Route53 records"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
        ]
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_role" "external_dns" {
  name        = "${local.cluster_name}-external-dns"
  description = "IRSA role for external-dns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:${local.external_dns_namespace}:${local.external_dns_service_account}"
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "external_dns_route53" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns_route53.arn
}
