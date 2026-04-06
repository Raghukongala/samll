# ─────────────────────────────────────────────
#  ECS Cluster
# ─────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.env}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.env}-cluster" })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# CloudWatch log group for all services
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project}/${var.env}"
  retention_in_days = 30
  tags              = var.tags
}
