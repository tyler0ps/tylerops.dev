# =============================================================================
# EC2 Instance for Plane
# =============================================================================

# Get latest Amazon Linux 2023 AMI
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

# EC2 Instance
resource "aws_instance" "plane" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.plane.id]
  iam_instance_profile   = aws_iam_instance_profile.plane.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true # Data is on separate EBS volume

    tags = {
      Name = "plane-root-volume"
    }
  }

  user_data = templatefile("${path.module}/templates/user-data.sh", {
    domain = var.domain_name
  })

  tags = {
    Name = "plane"
  }

  lifecycle {
    ignore_changes = [ami] # Don't recreate on AMI updates
  }
}

# Separate EBS Volume for persistent data (PostgreSQL, MinIO, Redis)
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

# Attach data volume to EC2
resource "aws_volume_attachment" "plane_data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.plane_data.id
  instance_id = aws_instance.plane.id
}

# Elastic IP
resource "aws_eip" "plane" {
  domain = "vpc"

  tags = {
    Name = "plane-eip"
  }
}

# Associate EIP with EC2
resource "aws_eip_association" "plane" {
  instance_id   = aws_instance.plane.id
  allocation_id = aws_eip.plane.id
}
