# =============================================================================
# ECS Service Module
# =============================================================================
# Creates ECS task definition and service with optional load balancer
# and service discovery integration
# =============================================================================

# =============================================================================
# ECS Task Definition
# =============================================================================
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}-${var.environment}-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        for key, value in var.environment_variables : {
          name  = key
          value = value
        }
      ]

      secrets = var.secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.service_name
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "python - <<'PY'\nimport sys,urllib.request\ntry:\n  r=urllib.request.urlopen('http://127.0.0.1:${var.container_port}/health', timeout=2)\n  sys.exit(0 if r.getcode()==200 else 1)\nexcept Exception:\n  sys.exit(1)\nPY"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-${var.service_name}"
      Service = var.service_name
    }
  )
}

# =============================================================================
# ECS Service
# =============================================================================
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-${var.environment}-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  
  # Only use launch_type when not using capacity providers
  launch_type = var.use_capacity_providers ? null : "FARGATE"

  # Use capacity provider strategy if enabled
  dynamic "capacity_provider_strategy" {
    for_each = var.use_capacity_providers ? [
      { capacity_provider = "FARGATE_SPOT", weight = 4, base = 0 },
      { capacity_provider = "FARGATE", weight = 1, base = 1 }
    ] : []
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  # Load balancer configuration (optional)
  dynamic "load_balancer" {
    for_each = var.enable_load_balancer ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  # Service discovery configuration (optional)
  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []
    content {
      registry_arn = var.service_discovery_service_arn
    }
  }

  # Deployment configuration
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  # Health check grace period (only if load balancer is enabled)
  health_check_grace_period_seconds = var.enable_load_balancer ? var.health_check_grace_period_seconds : null

  # Enable ECS managed tags
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  # Fargate capacity provider strategy
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
    base              = 0
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1  # At least 1 task on On-Demand
  }

  # Deployment circuit breaker
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-${var.service_name}"
      Service = var.service_name
    }
  )

  # Wait for load balancer to be ready
  depends_on = [aws_ecs_task_definition.main]
}
