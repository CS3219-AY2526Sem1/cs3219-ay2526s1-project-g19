# =============================================================================
# Application Load Balancer Module
# =============================================================================
# Creates:
# - Application Load Balancer in public subnets
# - Target groups for all 7 services
# - HTTP listener with path-based routing
# - Health checks for each service
# =============================================================================

locals {
  # Service configuration matching nginx.conf routing
  services = {
    frontend = {
      port        = 80
      protocol    = "HTTP"
      health_path = "/health"
      path_pattern = "/"
      priority    = 100  # Lowest priority (catch-all)
    }
    user-service = {
      port        = 8000
      protocol    = "HTTP"
      health_path = "/health"  # Django admin exists by default
      path_pattern = "/user-service-api/*"
      priority    = 10
    }
    question-service = {
      port        = 8000
      protocol    = "HTTP"
      health_path = "/health"  # Django admin exists by default
      path_pattern = "/question-service-api/*"
      priority    = 20
    }
    matching-service = {
      port        = 8000
      protocol    = "HTTP"
      health_path = "/health"  # FastAPI health endpoint
      path_pattern = "/matching-service-api/*"
      priority    = 30
    }
    history-service = {
      port        = 8000
      protocol    = "HTTP"
      health_path = "/health"  # Django admin exists by default
      path_pattern = "/history-service-api/*"
      priority    = 40
    }
    collaboration-service = {
      port        = 8000
      protocol    = "HTTP"
      health_path = "/health"  # FastAPI health endpoint
      path_pattern = "/collaboration-service-api/*"
      priority    = 50
    }
    chat-service = {
      port        = 8000
      protocol    = "HTTP"
      health_path = "/health"  # FastAPI health endpoint
      path_pattern = "/chat-service-api/*"
      priority    = 60
    }
  }
}

# =============================================================================
# Application Load Balancer
# =============================================================================
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # Enable deletion protection in production
  enable_deletion_protection = var.enable_deletion_protection

  # Enable cross-zone load balancing
  enable_cross_zone_load_balancing = true

  # Enable HTTP/2
  enable_http2 = true

  # Enable access logs (optional)
  dynamic "access_logs" {
    for_each = var.access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = "${var.project_name}-${var.environment}-alb"
      enabled = true
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# =============================================================================
# Target Groups (one per service)
# =============================================================================
resource "aws_lb_target_group" "services" {
  for_each = local.services

  name_prefix = substr("${var.project_name}-${each.key}-", 0, 6)  # Max 6 chars for prefix
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id

  # Target type for ECS Fargate
  target_type = "ip"

  # Deregistration delay (how long to wait before removing unhealthy targets)
  deregistration_delay = 30

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = each.value.health_path
    protocol            = each.value.protocol
    matcher             = "200,301,302"  # Accept 200 OK and redirects
  }

  # Stickiness for WebSocket services (collaboration and chat)
  dynamic "stickiness" {
    for_each = contains(["collaboration-service", "chat-service"], each.key) ? [1] : []
    content {
      type            = "lb_cookie"
      cookie_duration = 86400  # 24 hours
      enabled         = true
    }
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.key}-tg"
      Service = each.key
    }
  )

  # Ensure target group is created before ALB listener rules
  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# HTTP Listener (port 80)
# =============================================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action: forward to frontend (catch-all)
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["frontend"].arn
  }

  tags = var.tags
}

# =============================================================================
# Listener Rules (path-based routing)
# =============================================================================

# Rule for user-service-api
resource "aws_lb_listener_rule" "user_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = local.services["user-service"].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["user-service"].arn
  }

  condition {
    path_pattern {
      values = [local.services["user-service"].path_pattern]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "user-service-routing"
    }
  )
}

# Rule for question-service-api
resource "aws_lb_listener_rule" "question_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = local.services["question-service"].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["question-service"].arn
  }

  condition {
    path_pattern {
      values = [local.services["question-service"].path_pattern]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "question-service-routing"
    }
  )
}

# Rule for matching-service-api
resource "aws_lb_listener_rule" "matching_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = local.services["matching-service"].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["matching-service"].arn
  }

  condition {
    path_pattern {
      values = [local.services["matching-service"].path_pattern]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "matching-service-routing"
    }
  )
}

# Rule for history-service-api
resource "aws_lb_listener_rule" "history_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = local.services["history-service"].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["history-service"].arn
  }

  condition {
    path_pattern {
      values = [local.services["history-service"].path_pattern]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "history-service-routing"
    }
  )
}

# Rule for collaboration-service-api (WebSocket support)
resource "aws_lb_listener_rule" "collaboration_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = local.services["collaboration-service"].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["collaboration-service"].arn
  }

  condition {
    path_pattern {
      values = [local.services["collaboration-service"].path_pattern]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "collaboration-service-routing"
    }
  )
}

# Rule for chat-service-api (WebSocket support)
resource "aws_lb_listener_rule" "chat_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = local.services["chat-service"].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["chat-service"].arn
  }

  condition {
    path_pattern {
      values = [local.services["chat-service"].path_pattern]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "chat-service-routing"
    }
  )
}
# =============================================================================
# HTTPS Listener (port 443) - Optional, commented out
# =============================================================================
# Uncomment this section when you have an SSL certificate

# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.services["frontend"].arn
#   }
#
#   tags = var.tags
# }

# HTTP to HTTPS redirect (when HTTPS is enabled)
# resource "aws_lb_listener_rule" "redirect_http_to_https" {
#   listener_arn = aws_lb_listener.http.arn
#   priority     = 1
#
#   action {
#     type = "redirect"
#
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
#
#   condition {
#     path_pattern {
#       values = ["/*"]
#     }
#   }
# }

# =============================================================================
# CloudWatch Alarms
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  for_each = local.services

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when ${each.key} has unhealthy targets"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.services[each.key].arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  for_each = local.services

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1  # 1 second
  alarm_description   = "Alert when ${each.key} response time is high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.services[each.key].arn_suffix
  }

  tags = var.tags
}
