# =============================================================================
# IAM Role for Authentik EC2 (SSM + Self-attach EIP)
# =============================================================================

resource "aws_iam_role" "authentik" {
  name = "authentik-ec2-role"

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

# SSM Session Manager
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.authentik.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EBS self-attach + internal DNS registration at boot
resource "aws_iam_role_policy" "ec2_self_attach" {
  name = "authentik-ec2-self-attach"
  role = aws_iam_role.authentik.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Route53UpsertInternal"
        Effect = "Allow"
        Action = "route53:ChangeResourceRecordSets"
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Sid    = "EBSVolumeManagement"
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumes",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "authentik" {
  name = "authentik-instance-profile"
  role = aws_iam_role.authentik.name
}
