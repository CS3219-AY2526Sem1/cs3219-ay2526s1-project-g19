# =============================================================================
# Service Discovery Module (AWS Cloud Map)
# =============================================================================
# Creates private DNS namespace for service-to-service communication
# Services will be accessible via: service-name.namespace.local
# =============================================================================

# =============================================================================
# Private DNS Namespace
# =============================================================================
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}-${var.environment}.local"
  description = "Private DNS namespace for ${var.project_name} ${var.environment} services"
  vpc         = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-namespace"
    }
  )
}

# =============================================================================
# Service Discovery Services (one per microservice)
# =============================================================================
locals {
  backend_services = [
    "user-service",
    "question-service",
    "matching-service",
    "history-service",
    "collaboration-service",
    "chat-service"
  ]
}

resource "aws_service_discovery_service" "services" {
  for_each = toset(local.backend_services)

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.key}"
      Service = each.key
    }
  )
}
