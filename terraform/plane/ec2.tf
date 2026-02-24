# =============================================================================
# EC2 Resources for Plane
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

## Helper instance
# resource "aws_instance" "baker" {
#   ami                    = data.aws_ami.amazon_linux_2023.id
#   instance_type          = "t4g.small"
#   subnet_id              = aws_subnet.public.id
#   vpc_security_group_ids = [aws_security_group.plane.id]
#   iam_instance_profile   = aws_iam_instance_profile.plane.name

#   user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
#     domain = var.domain_name
#   }))

#   ebs_block_device {
#     device_name           = "/dev/xvda"
#     volume_size           = 8
#     volume_type           = "gp3"
#     encrypted             = true
#     delete_on_termination = true
#   }

#   tags = {
#     Name = "plane-ami-baker"
#   }

# }

# resource "aws_ebs_volume" "plane_data_baker" {
#   availability_zone = "${var.aws_region}a"
#   size              = 2
#   type              = "gp3"
#   encrypted         = true

#   tags = {
#     Name = "plane-data-volume-baker"
#   }

#   lifecycle {
#     prevent_destroy = false
#   }
# }

# resource "aws_volume_attachment" "plane_data_baker" {
#   device_name = "/dev/xvdf"
#   volume_id   = aws_ebs_volume.plane_data_baker.id
#   instance_id = aws_instance.baker.id
# }

# resource "aws_eip_association" "baker" {
#   instance_id   = aws_instance.baker.id
#   allocation_id = aws_eip.plane.id
# }

# Separate EBS Volume for persistent data (PostgreSQL, MinIO, Redis)
resource "aws_ebs_volume" "plane_data" {
  availability_zone = "${var.aws_region}a"
  size              = 2
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "plane-data-volume"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Elastic IP (static, Terraform managed)
resource "aws_eip" "plane" {
  domain = "vpc"

  tags = {
    Name = "plane-eip"
  }
}

# =============================================================================
# Auto Scaling Group for Plane
# =============================================================================

resource "aws_autoscaling_group" "plane" {
  name                = "plane-asg"
  vpc_zone_identifier = [aws_subnet.public.id]
  desired_capacity    = 1
  min_size            = 0
  max_size            = 1

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.plane.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  tag {
    key                 = "Name"
    value               = "plane"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Scheduled Scaling (Cost Optimization)
# ICT = UTC+7
# =============================================================================

# Scale down to 0 at 10 PM ICT (15:00 UTC)
resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "plane-scale-down"
  autoscaling_group_name = aws_autoscaling_group.plane.name
  recurrence             = "0 15 * * *"

  min_size         = 0
  max_size         = 1
  desired_capacity = 0
}

# Scale up to 1 at 7 AM ICT (00:00 UTC)
resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "plane-scale-up"
  autoscaling_group_name = aws_autoscaling_group.plane.name
  recurrence             = "0 0 * * *"

  min_size         = 0
  max_size         = 1
  desired_capacity = 1
}
