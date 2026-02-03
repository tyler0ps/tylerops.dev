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

# =============================================================================
# IAM Role for Lambda (Instance Manager)
# =============================================================================

resource "aws_iam_role" "lambda" {
  name = "plane-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda basic execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda policy for EC2 and SSM operations
resource "aws_iam_role_policy" "lambda_ec2" {
  name = "plane-lambda-ec2-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2InstanceManagement"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2VolumeManagement"
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2NetworkManagement"
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2LaunchTemplate"
        Effect = "Allow"
        Action = [
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMCommands"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      },
      {
        Sid      = "PassRoleToEC2"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.plane.arn
      }
    ]
  })
}
