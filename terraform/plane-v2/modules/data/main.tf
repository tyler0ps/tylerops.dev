# =============================================================================
# Data Module - PostgreSQL + Redis + RabbitMQ on EC2 with EBS
# =============================================================================

# Amazon Linux 2023 ARM64 AMI
data "aws_ami" "amazon_linux" {
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

# EC2 Instance for Data Services
resource "aws_instance" "data" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.data.id]
  iam_instance_profile   = var.iam_instance_profile_name

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
    mq_user     = var.mq_user
    mq_password = var.mq_password
    mq_vhost    = var.mq_vhost
    vpc_cidr    = var.vpc_cidr
  }))

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.name_prefix}-data"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# EBS Volume for Data (PostgreSQL, Redis, RabbitMQ)
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.data.availability_zone
  size              = var.ebs_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.name_prefix}-data-volume"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Attach EBS to EC2
resource "aws_volume_attachment" "data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.data.id
}
