# =============================================================================
# IAM Role for Caddy EC2 (SSM + EIP self-attach)
# =============================================================================

resource "aws_iam_role" "caddy" {
  name = "caddy-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "caddy_ssm" {
  role       = aws_iam_role.caddy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "caddy_route53" {
  name = "caddy-route53-update"
  role = aws_iam_role.caddy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "Route53Update"
      Effect = "Allow"
      Action = ["route53:ChangeResourceRecordSets"]
      Resource = "arn:aws:route53:::hostedzone/${data.aws_route53_zone.main.zone_id}"
    }]
  })
}

resource "aws_iam_role_policy" "caddy_s3_certs" {
  name = "caddy-s3-cert-storage"
  role = aws_iam_role.caddy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CaddyCertStorage"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.caddy_certs.arn,
        "${aws_s3_bucket.caddy_certs.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "caddy" {
  name = "caddy-instance-profile"
  role = aws_iam_role.caddy.name
}
