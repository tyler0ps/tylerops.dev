# =============================================================================
# EC2 Resources for Authentik
# =============================================================================

# Helper instance for rebaking AMI
# Uncomment → apply → wait for cloud-init to finish → create-image → comment out → re-apply
# resource "aws_instance" "baker" {
#   ami                    = data.aws_ami.al2023_arm64.id
#   instance_type          = "c6g.medium"
#   subnet_id              = data.terraform_remote_state.networking.outputs.public_subnet_id
#   vpc_security_group_ids = [aws_security_group.authentik.id]
#   iam_instance_profile   = aws_iam_instance_profile.authentik.name
#
#   user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
#     ebs_volume_id = aws_ebs_volume.authentik_data.id
#     eip_alloc_id  = aws_eip.authentik.id
#     aws_region    = var.aws_region
#     domain        = var.domain_name
#   }))
#
#   ebs_block_device {
#     device_name           = "/dev/xvda"
#     volume_size           = 8
#     volume_type           = "gp3"
#     encrypted             = true
#     delete_on_termination = true
#   }
#
#   tags = {
#     Name = "authentik-ami-baker"
#   }
# }

# Persistent data volume (PostgreSQL, Redis, media)
resource "aws_ebs_volume" "authentik_data" {
  availability_zone = "${var.aws_region}a"
  size              = 2
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "authentik-data-volume"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Elastic IP (static)
resource "aws_eip" "authentik" {
  domain = "vpc"

  tags = {
    Name = "authentik-eip"
  }
}

# =============================================================================
# Launch Template
# =============================================================================

resource "aws_launch_template" "authentik" {
  name        = "authentik-spot"
  description = "Launch template for Authentik spot instance"

  image_id      = data.aws_ami.authentik_custom.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.authentik.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.authentik.id]
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data-auth-plane.sh", {
    ebs_volume_id = aws_ebs_volume.authentik_data.id
    eip_alloc_id  = aws_eip.authentik.id
    aws_region    = var.aws_region
    domain        = var.domain_name

    # plane
    plane_ebs_volume_id = aws_ebs_volume.plane_data.id
    plane_domain        = var.domain_name_plane
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = "authentik"
      ManagedBy = "authentik-asg"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name      = "authentik-root-volume"
      ManagedBy = "authentik-asg"
    }
  }

  # Root volume
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 15
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
    Name = "authentik-launch-template"
  }
}

# =============================================================================
# Auto Scaling Group
# =============================================================================

resource "aws_autoscaling_group" "authentik" {
  name                = "authentik-asg"
  vpc_zone_identifier = [data.terraform_remote_state.networking.outputs.public_subnet_id]
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
        launch_template_id = aws_launch_template.authentik.id
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
    value               = "authentik"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

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
