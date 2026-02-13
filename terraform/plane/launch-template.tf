# =============================================================================
# Launch Template for Plane Spot Instance
# ASG uses this with mixed_instances_policy for spot allocation
# =============================================================================

resource "aws_launch_template" "plane" {
  name        = "plane-spot"
  description = "Launch template for Plane CE spot instances"

  image_id      = data.aws_ami.plane_custom.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.plane.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.plane.id]
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data-ami.sh", {
    ebs_volume_id = aws_ebs_volume.plane_data.id
    eip_alloc_id  = aws_eip.plane.id
    aws_region    = var.aws_region
    domain        = var.domain_name
  }))

  # Instance tags
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

  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
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
