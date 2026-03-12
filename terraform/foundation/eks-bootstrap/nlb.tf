# ============================================================
# NLB — Internet-facing Network Load Balancer
# TLS terminates here via ACM. Forwards plaintext HTTP to
# Envoy Gateway pods on port 80 via TargetGroupBinding.
# ============================================================

resource "aws_lb" "envoy" {
  name               = "${local.cluster_name}-envoy"
  load_balancer_type = "network"
  internal           = false
  subnets            = local.public_subnet_ids

  enable_deletion_protection = false

  tags = local.tags
}

resource "aws_lb_target_group" "envoy" {
  name        = "${local.cluster_name}-envoy"
  target_type = "ip"
  port        = 80
  protocol    = "TCP"
  vpc_id      = local.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "10080"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = local.tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.envoy.arn
  port              = 443
  protocol          = "TLS"
  certificate_arn   = aws_acm_certificate_validation.wildcard.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.envoy.arn
  }

  tags = local.tags
}
