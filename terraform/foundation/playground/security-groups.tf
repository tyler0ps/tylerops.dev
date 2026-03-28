resource "aws_security_group" "playground" {
  name        = "playground-sg"
  description = "Security group for Ubuntu Playground (private subnet)"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  # All outbound — required for GitHub API, AWS APIs via NAT instance
  egress {
    description = "All outbound via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "playground-sg"
  }
}
