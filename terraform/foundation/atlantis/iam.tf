# =============================================================================
# IAM Role for Atlantis EC2
# =============================================================================

resource "aws_iam_role" "atlantis" {
  name = "atlantis-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# SSM Session Manager (no SSH access needed)
resource "aws_iam_role_policy_attachment" "atlantis_ssm" {
  role       = aws_iam_role.atlantis.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AdministratorAccess — required because Atlantis manages IAM, EKS, Lambda, etc.
resource "aws_iam_role_policy_attachment" "atlantis_admin" {
  role       = aws_iam_role.atlantis.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "atlantis" {
  name = "atlantis-instance-profile"
  role = aws_iam_role.atlantis.name
}
