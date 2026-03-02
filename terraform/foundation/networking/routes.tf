# Private route tables for EKS nodes
# Routes 0.0.0.0/0 are added by the fck-nat module (nat-instance.tf)

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "management-private-rt-a"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "management-private-rt-b"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# Pod subnets share the same private route tables (NAT access)
resource "aws_route_table_association" "pods_a" {
  subnet_id      = aws_subnet.pods_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "pods_b" {
  subnet_id      = aws_subnet.pods_b.id
  route_table_id = aws_route_table.private_b.id
}
