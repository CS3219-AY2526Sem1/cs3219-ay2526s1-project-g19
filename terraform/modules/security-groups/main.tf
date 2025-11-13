# =============================================================================
# Security Groups Module - Main Configuration
# =============================================================================
# Creates security groups for:
# - Application Load Balancer (ALB)
# - ECS Tasks (all microservices)
# - RDS PostgreSQL (4 separate databases)
# - ElastiCache Redis (3 separate clusters)
# =============================================================================

# =============================================================================
# ALB Security Group
# =============================================================================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
    }
  )
}

# ALB Ingress: HTTP from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from anywhere"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "alb-http-ingress"
  }
}

# ALB Ingress: HTTPS from anywhere (for future use)
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from anywhere"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "alb-https-ingress"
  }
}

# ALB Egress: Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "alb-all-egress"
  }
}

# =============================================================================
# ECS Tasks Security Group
# =============================================================================
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Security group for ECS tasks (all microservices)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-sg"
    }
  )
}

# ECS Ingress: Port 8000 from ALB (backend services)
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_8000" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow port 8000 from ALB for backend services"

  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "ecs-from-alb-8000"
  }
}

# ECS Ingress: Port 80 from ALB (frontend)
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_80" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow port 80 from ALB for frontend"

  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "ecs-from-alb-80"
  }
}

# ECS Ingress: Allow communication between ECS tasks (service discovery)
resource "aws_vpc_security_group_ingress_rule" "ecs_internal" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow communication between ECS tasks"

  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "ecs-internal-communication"
  }
}

# ECS Egress: Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "ecs-all-egress"
  }
}

# =============================================================================
# RDS PostgreSQL Security Groups (4 databases)
# =============================================================================
locals {
  db_names = ["user", "question", "matching", "history"]
}

resource "aws_security_group" "db" {
  for_each = toset(local.db_names)

  name        = "${var.project_name}-${var.environment}-${each.key}-db-sg"
  description = "Security group for ${each.key} PostgreSQL database"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.key}-db-sg"
      Service = "${each.key}-service"
    }
  )
}

# DB Ingress: PostgreSQL from ECS tasks
resource "aws_vpc_security_group_ingress_rule" "db_from_ecs" {
  for_each = toset(local.db_names)

  security_group_id = aws_security_group.db[each.key].id
  description       = "Allow PostgreSQL from ECS tasks"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "${each.key}-db-from-ecs"
  }
}

# DB Ingress: PostgreSQL from local IP for migrations/development
resource "aws_vpc_security_group_ingress_rule" "db_from_local_ip" {
  for_each = toset(local.db_names)

  security_group_id = aws_security_group.db[each.key].id
  description       = "Allow PostgreSQL from Local IP for Migrations"

  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  # 🛑 ACTION: Use the IP you just found, 137.132.26.199
  cidr_ipv4         = "137.132.26.199/32" 

  tags = {
    Name = "${each.key}-db-from-local-ip"
  }
}

# DB Egress: Allow all outbound (for updates, etc.)
resource "aws_vpc_security_group_egress_rule" "db_all" {
  for_each = toset(local.db_names)

  security_group_id = aws_security_group.db[each.key].id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "${each.key}-db-egress"
  }
}

# =============================================================================
# ElastiCache Redis Security Groups (3 clusters)
# =============================================================================
locals {
  redis_names = ["matching", "collaboration", "chat"]
}

resource "aws_security_group" "redis" {
  for_each = toset(local.redis_names)

  name        = "${var.project_name}-${var.environment}-${each.key}-redis-sg"
  description = "Security group for ${each.key} Redis cluster"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.key}-redis-sg"
      Service = "${each.key}-service"
    }
  )
}

# Redis Ingress: Redis from ECS tasks
resource "aws_vpc_security_group_ingress_rule" "redis_from_ecs" {
  for_each = toset(local.redis_names)

  security_group_id = aws_security_group.redis[each.key].id
  description       = "Allow Redis from ECS tasks"

  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "${each.key}-redis-from-ecs"
  }
}

# Redis Egress: Allow all outbound
resource "aws_vpc_security_group_egress_rule" "redis_all" {
  for_each = toset(local.redis_names)

  security_group_id = aws_security_group.redis[each.key].id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "${each.key}-redis-egress"
  }
}
