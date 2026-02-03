# =============================================================================
# EC2 Resources for Plane
# NOTE: Instance is managed by Lambda, not Terraform
# =============================================================================

# Get latest Amazon Linux 2023 AMI (for reference only)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# REMOVED: aws_instance.plane
# Instance is now managed by Lambda via Launch Template
# Lambda creates/terminates instances based on schedule and spot interruptions
# Keep this code for reference only, not applied by Terraform
# =============================================================================

# EC2 Instance - Used to create AMI
# resource "aws_instance" "plane" {
#   ami                    = var.use_custom_ami ? data.aws_ami.plane_custom.id : data.aws_ami.amazon_linux_2023.id
#   instance_type          = var.instance_type
#   subnet_id              = aws_subnet.public.id
#   vpc_security_group_ids = [aws_security_group.plane.id]
#   iam_instance_profile   = aws_iam_instance_profile.plane.name

#   root_block_device {
#     volume_size           = 30
#     volume_type           = "gp3"
#     encrypted             = true
#     delete_on_termination = true # Data is on separate EBS volume

#     tags = {
#       Name = "plane-root-volume"
#     }
#   }

#   user_data = var.use_custom_ami ? templatefile("${path.module}/templates/user-data-ami.sh", {
#     domain = var.domain_name
#   }) : templatefile("${path.module}/templates/user-data.sh", {
#     domain = var.domain_name
#   })

#   tags = {
#     Name = "plane"
#   }

#   lifecycle {
#     ignore_changes = [ami] # Don't recreate on AMI updates
#   }
# }


# Separate EBS Volume for persistent data (PostgreSQL, MinIO, Redis)
# This is managed by Terraform and attached by Lambda to new instances
resource "aws_ebs_volume" "plane_data" {
  availability_zone = "${var.aws_region}a"
  size              = 30
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "plane-data-volume"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# REMOVED: aws_volume_attachment.plane_data
# Lambda handles volume attachment after instance creation
# =============================================================================

# Elastic IP (static, Terraform managed)
# Lambda associates this to new instances
resource "aws_eip" "plane" {
  domain = "vpc"

  tags = {
    Name = "plane-eip"
  }
}

# =============================================================================
# REMOVED: aws_eip_association.plane
# Lambda handles EIP association after instance creation
# =============================================================================

# Data source to find current Lambda-managed instance (for outputs)
data "aws_instances" "plane_managed" {
  filter {
    name   = "tag:ManagedBy"
    values = ["plane-lambda"]
  }

  filter {
    name   = "instance-state-name"
    values = ["pending", "running", "stopping", "stopped"]
  }
}
