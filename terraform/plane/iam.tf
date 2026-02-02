# =============================================================================
# IAM Role for EC2 (SSM Session Manager access)
# =============================================================================

resource "aws_iam_role" "plane" {
  name = "plane-ec2-role"

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

# Attach SSM managed policy for Session Manager
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "plane" {
  name = "plane-instance-profile"
  role = aws_iam_role.plane.name
}
