# =============================================================================
# EC2 Resources for Plane
# =============================================================================

# Persistent data volume (PostgreSQL, MinIO, Redis)
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

# =============================================================================
# Launch Template
# =============================================================================

resource "aws_launch_template" "plane" {
  name        = "plane-spot"
  description = "Launch template for Plane spot instance"

  image_id      = data.aws_ami.plane_custom.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.plane.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.plane.id]
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data-ami.sh", {
    ebs_volume_id    = aws_ebs_volume.plane_data.id
    aws_region       = var.aws_region
    domain           = var.domain_name
    internal_zone_id = data.terraform_remote_state.networking.outputs.internal_zone_id
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = "plane"
      ManagedBy = "plane-asg"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name      = "plane-root-volume"
      ManagedBy = "plane-asg"
    }
  }

  # Root volume
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "plane-launch-template"
  }
}

# =============================================================================
# Auto Scaling Group
# =============================================================================

resource "aws_autoscaling_group" "plane" {
  name                = "plane-asg"
  vpc_zone_identifier = [tolist(data.terraform_remote_state.networking.outputs.private_subnet_ids)[0]]
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

# Scale down at 22:00 Vietnam (15:00 UTC) — to save cost overnight
resource "aws_autoscaling_schedule" "plane_scale_down" {
  scheduled_action_name  = "plane-scale-down"
  autoscaling_group_name = aws_autoscaling_group.plane.name
  recurrence             = "0 15 * * *" # 22:00 Asia/Ho_Chi_Minh (UTC+7)
  desired_capacity       = 0
  min_size               = 0
  max_size               = 1
}

# Scale up at 06:00 Vietnam (23:00 UTC)
# resource "aws_autoscaling_schedule" "plane_scale_up" {
#   scheduled_action_name  = "plane-scale-up"
#   autoscaling_group_name = aws_autoscaling_group.plane.name
#   recurrence             = "0 23 * * *" # 06:00 Asia/Ho_Chi_Minh (UTC+7)
#   desired_capacity       = 1
#   min_size               = 0
#   max_size               = 1
# }
