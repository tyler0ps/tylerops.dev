# NAT Instance using fck-nat (https://fck-nat.dev)
# Replaces NAT Gateway — significantly cheaper for low-traffic workloads

module "nat" {
  source  = "RaJiska/fck-nat/aws"
  version = "~> 1.3"

  name      = "management-nat"
  vpc_id    = aws_vpc.main.id
  subnet_id = aws_subnet.public.id # az-a public subnet

  # Use spot instances for the NAT instance to further reduce costs
  use_spot_instances = true

  # Automatically add 0.0.0.0/0 → NAT instance routes to private route tables
  update_route_tables = true
  route_tables_ids = {
    private-a = aws_route_table.private_a.id
    private-b = aws_route_table.private_b.id
  }
}
