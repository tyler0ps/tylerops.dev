# =============================================================================
# EC2 Resources for Caddy Reverse Proxy
# =============================================================================

# =============================================================================
# Launch Template
# =============================================================================

resource "aws_launch_template" "caddy" {
  name        = "caddy-spot"
  description = "Launch template for Caddy reverse proxy spot instance"

  image_id      = data.aws_ami.caddy.id
  instance_type = var.instance_types[0]

  iam_instance_profile {
    name = aws_iam_instance_profile.caddy.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.caddy.id]
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    aws_region       = var.aws_region
    atlantis_domain  = var.atlantis_domain
    authentik_domain = var.authentik_domain
    plane_domain     = var.plane_domain
    hosted_zone_id   = data.aws_route53_zone.main.zone_id
    cert_bucket      = aws_s3_bucket.caddy_certs.bucket
    acme_email       = var.acme_email
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 4
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
      Name      = "caddy"
      ManagedBy = "caddy-asg"
    }
  }

  tags = {
    Name = "caddy-launch-template"
  }
}

# =============================================================================
# Auto Scaling Group
# =============================================================================

resource "aws_autoscaling_group" "caddy" {
  name                = "caddy-asg"
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
        launch_template_id = aws_launch_template.caddy.id
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
    value               = "caddy"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
