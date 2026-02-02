# =============================================================================
# EC2 Instance for Vikunja
# =============================================================================

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "vikunja" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.vikunja.id]
  iam_instance_profile   = aws_iam_instance_profile.vikunja.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false # Keep data on instance termination

    tags = {
      Name = "vikunja-root-volume"
    }
  }

  user_data = templatefile("${path.module}/templates/user-data.sh", {
    domain     = var.domain_name
    jwt_secret = var.vikunja_jwt_secret
  })

  tags = {
    Name = "vikunja"
  }

  lifecycle {
    ignore_changes = [ami] # Don't recreate on AMI updates
  }
}

# Elastic IP
resource "aws_eip" "vikunja" {
  domain = "vpc"

  tags = {
    Name = "vikunja-eip"
  }
}

# Associate EIP with EC2
resource "aws_eip_association" "vikunja" {
  instance_id   = aws_instance.vikunja.id
  allocation_id = aws_eip.vikunja.id
}
