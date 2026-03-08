# =============================================================================
# S3 Bucket for Caddy TLS Certificate Storage
# Persists certs across spot instance replacements to avoid Let's Encrypt rate limits
# =============================================================================

resource "aws_s3_bucket" "caddy_certs" {
  bucket = "caddy-tls-certs-tylerops"

  tags = {
    Name    = "caddy-tls-certs"
    Purpose = "caddy-cert-storage"
  }
}

resource "aws_s3_bucket_versioning" "caddy_certs" {
  bucket = aws_s3_bucket.caddy_certs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "caddy_certs" {
  bucket = aws_s3_bucket.caddy_certs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "caddy_certs" {
  bucket = aws_s3_bucket.caddy_certs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
