# ─────────────────────────────────────────────
#  Service Discovery (Cloud Map)
#  Allows services to call each other by DNS name
# ─────────────────────────────────────────────

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project}-${var.env}.local"
  description = "Private DNS namespace for ${var.project} ${var.env}"
  vpc         = var.vpc_id
  tags        = var.tags
}

resource "aws_service_discovery_service" "services" {
  for_each = toset(["api-gateway", "user-service", "product-service", "order-service"])

  name = each.key

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.main.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.tags
}

# ─────────────────────────────────────────────
#  ECS Services
# ─────────────────────────────────────────────

locals {
  service_configs = {
    api-gateway = {
      desired_count    = var.env == "prod" ? 2 : 1
      target_group_arn = aws_lb_target_group.api_gateway.arn
      container_port   = 8000
    }
    user-service = {
      desired_count    = var.env == "prod" ? 2 : 1
      target_group_arn = aws_lb_target_group.services["user-service"].arn
      container_port   = 8001
    }
    product-service = {
      desired_count    = var.env == "prod" ? 2 : 1
      target_group_arn = aws_lb_target_group.services["product-service"].arn
      container_port   = 8002
    }
    order-service = {
      desired_count    = var.env == "prod" ? 2 : 1
      target_group_arn = aws_lb_target_group.services["order-service"].arn
      container_port   = 8003
    }
  }
}

resource "aws_ecs_service" "services" {
  for_each = local.service_configs

  name                               = each.key
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.services[each.key].arn
  desired_count                      = each.value.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60
  enable_execute_command             = true  # ECS Exec for debugging

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = each.value.target_group_arn
    container_name   = each.key
    container_port   = each.value.container_port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services[each.key].arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  tags = merge(var.tags, { Service = each.key })

  lifecycle {
    ignore_changes = [desired_count, task_definition]  # managed by CI/CD
  }
}

# ─────────────────────────────────────────────
#  Auto Scaling
# ─────────────────────────────────────────────

resource "aws_appautoscaling_target" "services" {
  for_each = local.service_configs

  max_capacity       = var.env == "prod" ? 10 : 3
  min_capacity       = var.env == "prod" ? 2 : 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${each.key}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.services]
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.service_configs

  name               = "${var.project}-${var.env}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory" {
  for_each = local.service_configs

  name               = "${var.project}-${var.env}-${each.key}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
