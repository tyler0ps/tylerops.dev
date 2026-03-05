# ============================================================
# CERT-MANAGER — IRSA
# ============================================================

locals {
  cert_manager_namespace       = "cert-manager"
  cert_manager_service_account = "cert-manager"
  cert_manager_oidc_url        = trimprefix(module.eks_karpenter.cluster_oidc_issuer_url, "https://")
}

resource "aws_iam_policy" "cert_manager_route53" {
  name        = "${local.cluster_name}-cert-manager-route53"
  description = "Allow cert-manager to manage Route53 records for ACME DNS-01 challenges"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect   = "Allow"
        Action   = "route53:ListHostedZonesByName"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_role" "cert_manager" {
  name        = "${local.cluster_name}-cert-manager"
  description = "IRSA role for cert-manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks_karpenter.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.cert_manager_oidc_url}:sub" = "system:serviceaccount:${local.cert_manager_namespace}:${local.cert_manager_service_account}"
          "${local.cert_manager_oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cert_manager_route53" {
  role       = aws_iam_role.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager_route53.arn
}
