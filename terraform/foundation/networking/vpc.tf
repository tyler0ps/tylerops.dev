# =============================================================================
# VPC - Management account shared networking
# CIDR: 10.0.0.0/16 (non-overlapping with plane 10.4.0.0/16)
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "management-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "management-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "management-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "management-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Public Subnet az-b (for EKS multi-AZ)
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "management-public-subnet-b"
  }
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Private Subnet az-a (EKS nodes)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "management-private-subnet-a"
  }
}

# Private Subnet az-b (EKS nodes)
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "management-private-subnet-b"
  }
}

# ============================================================
# Secondary CIDR - Pod IPs (100.64.0.0/16 CGNAT range)
# Nodes use 10.0.x.0/24, Pods use 100.64.x.0/19 → 8190 IPs/AZ
# ============================================================
resource "aws_vpc_ipv4_cidr_block_association" "pods" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "100.64.0.0/16"
}

resource "aws_subnet" "pods_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "100.64.0.0/19"
  availability_zone = "${var.aws_region}a"

  depends_on = [aws_vpc_ipv4_cidr_block_association.pods]

  tags = {
    Name = "management-pods-subnet-a"
  }
}

resource "aws_subnet" "pods_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "100.64.32.0/19"
  availability_zone = "${var.aws_region}b"

  depends_on = [aws_vpc_ipv4_cidr_block_association.pods]

  tags = {
    Name = "management-pods-subnet-b"
  }
}
