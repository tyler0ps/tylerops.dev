# =============================================================================
# IAM Role for EC2 (SSM + S3 access)
# =============================================================================

resource "aws_iam_role" "plane" {
  name = "plane-v2-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# SSM managed policy for Session Manager
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 access policy for Plane uploads
resource "aws_iam_role_policy" "s3_access" {
  name = "plane-v2-s3-access"
  role = aws_iam_role.plane.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.uploads.arn,
          "${aws_s3_bucket.uploads.arn}/*"
        ]
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "plane" {
  name = "plane-v2-instance-profile"
  role = aws_iam_role.plane.name
}
