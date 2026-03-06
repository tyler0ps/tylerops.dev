# NAT Instance using fck-nat (https://fck-nat.dev)
# Replaces NAT Gateway — significantly cheaper for low-traffic workloads

module "nat" {
  source  = "RaJiska/fck-nat/aws"
  version = "~> 1.3"

  name      = "management-nat"
  vpc_id    = aws_vpc.main.id
  subnet_id = aws_subnet.public.id # az-a public subnet

  instance_type        = "t4g.nano"
  ebs_root_volume_size = 4

  # Use spot instances for the NAT instance to further reduce costs
  use_spot_instances = true

  # Automatically add 0.0.0.0/0 → NAT instance routes to private route tables
  update_route_tables = true
  route_tables_ids = {
    private-a = aws_route_table.private_a.id
    private-b = aws_route_table.private_b.id
  }
}

# Scale down at 22:00 Vietnam (15:00 UTC) — shut off NAT to save cost overnight
resource "aws_autoscaling_schedule" "nat_scale_down" {
  scheduled_action_name  = "nat-scale-down"
  autoscaling_group_name = module.nat.name
  recurrence             = "0 15 * * *" # 22:00 Asia/Ho_Chi_Minh (UTC+7)
  desired_capacity       = 0
  min_size               = 0
  max_size               = 1
}

# Scale up at 07:00 Vietnam (00:00 UTC) — bring NAT back online in the morning
# resource "aws_autoscaling_schedule" "nat_scale_up" {
#   scheduled_action_name  = "nat-scale-up"
#   autoscaling_group_name = module.nat.name
#   recurrence             = "0 0 * * *" # 07:00 Asia/Ho_Chi_Minh (UTC+7)
#   desired_capacity       = 1
#   min_size               = 1
#   max_size               = 1
# }
