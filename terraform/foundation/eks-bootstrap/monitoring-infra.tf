# ============================================================
# MONITORING — Infrastructure Prerequisites
# S3 bucket (Loki storage), IRSA role, namespace, secrets
# ============================================================

locals {
  monitoring_namespace = "monitoring"
  loki_service_account = "loki"
}

# ---- S3 Bucket for Loki log storage ----

resource "aws_s3_bucket" "loki" {
  bucket = "${local.cluster_name}-loki-chunks"
  tags   = local.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket = aws_s3_bucket.loki.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- IAM Policy for Loki → S3 ----

resource "aws_iam_policy" "loki_s3" {
  name        = "${local.cluster_name}-loki-s3"
  description = "Allow Loki to read/write S3 for log storage"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.loki.arn,
          "${aws_s3_bucket.loki.arn}/*",
        ]
      },
    ]
  })

  tags = local.tags
}

# ---- IRSA Role for Loki ----

resource "aws_iam_role" "loki" {
  name        = "${local.cluster_name}-loki"
  description = "IRSA role for Loki log storage access"

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
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:${local.monitoring_namespace}:${local.loki_service_account}"
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "loki_s3" {
  role       = aws_iam_role.loki.name
  policy_arn = aws_iam_policy.loki_s3.arn
}

# ---- monitoring namespace ----
# Created explicitly so secrets can be provisioned before ArgoCD syncs.

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = local.monitoring_namespace
  }
}

# ---- Grafana OAuth Secret ----

resource "kubernetes_secret_v1" "grafana_oauth" {
  metadata {
    name      = "grafana-oauth"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = data.aws_ssm_parameter.grafana_oauth_client_secret.value
  }
}
