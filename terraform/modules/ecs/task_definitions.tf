# ─────────────────────────────────────────────
#  Task Definitions  (one per microservice)
# ─────────────────────────────────────────────

locals {
  services = {
    api-gateway = {
      port        = 8000
      cpu         = 512
      memory      = 1024
      image       = "${var.ecr_base}/api-gateway:${var.image_tag}"
      environment = [
        { name = "PORT",                value = "8000" },
        { name = "USER_SERVICE_URL",    value = "http://user-service.${var.project}-${var.env}.local:8001" },
        { name = "PRODUCT_SERVICE_URL", value = "http://product-service.${var.project}-${var.env}.local:8002" },
        { name = "ORDER_SERVICE_URL",   value = "http://order-service.${var.project}-${var.env}.local:8003" },
      ]
    }
    user-service = {
      port        = 8001
      cpu         = 256
      memory      = 512
      image       = "${var.ecr_base}/user-service:${var.image_tag}"
      environment = [
        { name = "PORT", value = "8001" },
      ]
    }
    product-service = {
      port        = 8002
      cpu         = 256
      memory      = 512
      image       = "${var.ecr_base}/product-service:${var.image_tag}"
      environment = [
        { name = "PORT", value = "8002" },
      ]
    }
    order-service = {
      port        = 8003
      cpu         = 256
      memory      = 512
      image       = "${var.ecr_base}/order-service:${var.image_tag}"
      environment = [
        { name = "PORT",                value = "8003" },
        { name = "USER_SERVICE_URL",    value = "http://user-service.${var.project}-${var.env}.local:8001" },
        { name = "PRODUCT_SERVICE_URL", value = "http://product-service.${var.project}-${var.env}.local:8002" },
      ]
    }
  }
}

resource "aws_ecs_task_definition" "services" {
  for_each = local.services

  family                   = "${var.project}-${var.env}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = each.value.image
      essential = true

      portMappings = [
        {
          containerPort = each.value.port
          hostPort      = each.value.port
          protocol      = "tcp"
        }
      ]

      environment = each.value.environment

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.key
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.tags, { Service = each.key })
}
