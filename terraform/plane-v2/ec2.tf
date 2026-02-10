# =============================================================================
# Plane EC2 Instance (Stateless Compute)
# =============================================================================

# Plane Commercial AMI (baked)
data "aws_ami" "plane" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["plane-commercial-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# Data Module (PostgreSQL + Redis + RabbitMQ)
module "data" {
  source = "./modules/data"

  vpc_id                    = aws_vpc.main.id
  subnet_id                 = aws_subnet.public.id
  vpc_cidr                  = var.vpc_cidr
  plane_security_group_id   = aws_security_group.plane.id
  instance_type             = "m6g.medium"
  ebs_size                  = 30
  db_name                   = "plane"
  db_user                   = "plane"
  db_password               = var.db_password
  mq_user                   = "plane"
  mq_password               = var.mq_password
  mq_vhost                  = "plane"
  private_zone_name         = "plane.internal"
  iam_instance_profile_name = aws_iam_instance_profile.plane.name
  name_prefix               = "plane-v2"
}

# Elastic IP for Plane
resource "aws_eip" "plane" {
  domain = "vpc"

  tags = {
    Name = "plane-v2-eip"
  }
}

# EBS Volume for Plane Data (caddy certs only)
resource "aws_ebs_volume" "plane_data" {
  availability_zone = "${var.aws_region}a"
  size              = 10
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "plane-v2-caddy-data"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# =============================================================================
# Launch Template for Plane (Spot Instance)
# =============================================================================
resource "aws_launch_template" "plane" {
  name_prefix   = "plane-v2-"
  image_id      = data.aws_ami.plane.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.plane.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.plane.id]
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data-ami.sh", {
    domain        = var.domain_name
    db_host       = module.data.db_dns_name
    db_name       = "plane"
    db_user       = "plane"
    db_password   = var.db_password
    redis_host    = module.data.redis_dns_name
    mq_host       = module.data.mq_dns_name
    mq_user       = "plane"
    mq_password   = var.mq_password
    mq_vhost      = "plane"
    s3_bucket     = aws_s3_bucket.uploads.bucket
    s3_region     = var.aws_region
    s3_access_key = aws_iam_access_key.plane_s3.id
    s3_secret_key = aws_iam_access_key.plane_s3.secret
    eip_alloc_id  = aws_eip.plane.id
    ebs_volume_id = aws_ebs_volume.plane_data.id
    aws_region    = var.aws_region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "plane-v2"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [module.data]
}

# =============================================================================
# Auto Scaling Group for Plane
# =============================================================================
resource "aws_autoscaling_group" "plane" {
  name                = "plane-v2-asg"
  vpc_zone_identifier = [aws_subnet.public.id]
  desired_capacity    = 1
  min_size            = 0 # Allow scaling to 0 for cost savings
  max_size            = 1

  launch_template {
    id      = aws_launch_template.plane.id
    version = "$Latest"
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
    value               = "plane-v2"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Scheduled Scaling (Cost Optimization)
# ICT = UTC+7, so 10 PM ICT = 15:00 UTC, 6 AM ICT = 23:00 UTC (prev day)
# =============================================================================

# Scale down to 0 at 10 PM ICT (15:00 UTC)
resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "plane-v2-scale-down"
  autoscaling_group_name = aws_autoscaling_group.plane.name
  recurrence             = "0 15 * * *" # 15:00 UTC = 22:00 ICT

  min_size         = 0
  max_size         = 1
  desired_capacity = 0
}

# Scale up to 1 at 6 AM ICT (23:00 UTC previous day)
resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "plane-v2-scale-up"
  autoscaling_group_name = aws_autoscaling_group.plane.name
  recurrence             = "0 23 * * *" # 23:00 UTC = 06:00 ICT next day

  min_size         = 0
  max_size         = 1
  desired_capacity = 1
}
