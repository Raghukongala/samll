# ─────────────────────────────────────────────
#  Application Load Balancer
# ─────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.project}-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.env == "prod"

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.env}-alb" })
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project}-${var.env}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.env != "prod"
  tags          = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    expiration { days = 30 }
  }
}

data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = data.aws_elb_service_account.main.arn }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

# ── Target Groups ──

resource "aws_lb_target_group" "api_gateway" {
  name        = "${var.project}-${var.env}-api-gw-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = var.tags
}

# Individual service target groups (useful for direct access / debugging)
resource "aws_lb_target_group" "services" {
  for_each = {
    user-service    = 8001
    product-service = 8002
    order-service   = 8003
  }

  name        = "${var.project}-${var.env}-${substr(each.key, 0, 16)}-tg"
  port        = each.value
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }

  tags = var.tags
}

# ── HTTP Listener  (redirects to HTTPS in prod, plain HTTP in dev) ──

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}

# ── Listener Rules – path-based routing ──
#  /users/*     → user-service
#  /products/*  → product-service
#  /orders/*    → order-service
#  /*           → api-gateway (default)

resource "aws_lb_listener_rule" "users" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["user-service"].arn
  }

  condition {
    path_pattern { values = ["/users", "/users/*"] }
  }
}

resource "aws_lb_listener_rule" "products" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["product-service"].arn
  }

  condition {
    path_pattern { values = ["/products", "/products/*"] }
  }
}

resource "aws_lb_listener_rule" "orders" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["order-service"].arn
  }

  condition {
    path_pattern { values = ["/orders", "/orders/*"] }
  }
}
