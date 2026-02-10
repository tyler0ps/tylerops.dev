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

# Plane EC2 Spot Instance (Stateless - only app containers)
resource "aws_instance" "plane" {
  ami                    = data.aws_ami.plane.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.plane.id]
  iam_instance_profile   = aws_iam_instance_profile.plane.name

  instance_market_options {
    market_type = "spot"
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
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "plane-v2"
  }

  depends_on = [module.data]

  lifecycle {
    ignore_changes = [ami]
  }
}

# Attach EBS to Plane EC2
resource "aws_volume_attachment" "plane_data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.plane_data.id
  instance_id = aws_instance.plane.id
}

# Associate EIP to Plane EC2
resource "aws_eip_association" "plane" {
  instance_id   = aws_instance.plane.id
  allocation_id = aws_eip.plane.id
}
