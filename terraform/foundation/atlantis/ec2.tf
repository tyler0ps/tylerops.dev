# =============================================================================
# EC2 Resources for Atlantis (private subnet, no public IP)
# =============================================================================

# =============================================================================
# Launch Template
# =============================================================================

resource "aws_launch_template" "atlantis" {
  name        = "atlantis-spot"
  description = "Launch template for Atlantis spot instance (private subnet)"

  image_id      = data.aws_ami.atlantis.id
  instance_type = var.instance_types[0]

  iam_instance_profile {
    name = aws_iam_instance_profile.atlantis.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.atlantis.id]
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    aws_region       = var.aws_region
    internal_zone_id = data.terraform_remote_state.networking.outputs.internal_zone_id
    atlantis_domain  = var.atlantis_domain
    repo_allowlist   = var.repo_allowlist
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = "atlantis"
      ManagedBy = "atlantis-asg"
    }
  }

  tags = {
    Name = "atlantis-launch-template"
  }
}

# =============================================================================
# Auto Scaling Group
# =============================================================================

resource "aws_autoscaling_group" "atlantis" {
  name                = "atlantis-asg"
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
        launch_template_id = aws_launch_template.atlantis.id
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
    value               = "atlantis"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
