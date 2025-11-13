# =============================================================================
# PeerPrep AWS ECS Infrastructure - Main Configuration
# =============================================================================
# Phase 1: VPC and Networking Foundation
# This file orchestrates all infrastructure modules
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Uncomment to use S3 backend for state management
  # backend "s3" {
  #   bucket         = "peerprep-terraform-state"
  #   key            = "ecs/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "peerprep-terraform-locks"
  # }
}

# =============================================================================
# Provider Configuration
# =============================================================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "PeerPrep-Team"
    }
  }
}

# =============================================================================
# Data Sources
# =============================================================================
# Get available availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# =============================================================================
# Phase 1: VPC and Networking
# =============================================================================
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr

  # Use first 2 availability zones for multi-AZ setup
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  # Subnet CIDR blocks
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # NAT Gateway configuration
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway # Set to true for cost savings

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}

# =============================================================================
# Phase 1: Security Groups
# =============================================================================
module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  # CIDR blocks for access control
  vpc_cidr = var.vpc_cidr

  tags = var.tags
}

# =============================================================================
# Phase 2: RDS PostgreSQL - 4 Separate Instances
# =============================================================================
# DB Subnet Group for RDS instances
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-subnet-group"
    }
  )
}

# User Database
module "rds_user" {
  source = "./modules/rds"

  name_prefix         = "${var.project_name}-${var.environment}-user"
  vpc_id              = module.vpc.vpc_id
  database_subnet_ids = module.vpc.private_subnet_ids
  db_subnet_group_name = aws_db_subnet_group.main.name
  security_group_ids  = [module.security_groups.user_db_security_group_id]

  # Database configuration
  engine_version      = var.db_engine_version
  db_instance_class   = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  database_names      = ["user_db"]
  master_username     = var.db_username
  master_password     = var.db_password

  # High availability
  multi_az = var.db_multi_az

  # Backups
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # Safety
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot
  apply_immediately   = false

  tags = var.tags
}

# Question Database
module "rds_question" {
  source = "./modules/rds"

  name_prefix          = "${var.project_name}-${var.environment}-question"
  vpc_id               = module.vpc.vpc_id
  database_subnet_ids  = module.vpc.private_subnet_ids
  db_subnet_group_name = aws_db_subnet_group.main.name
  security_group_ids   = [module.security_groups.question_db_security_group_id]

  # Database configuration
  engine_version        = var.db_engine_version
  db_instance_class     = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  database_names        = ["question_db"]
  master_username       = var.db_username
  master_password       = var.db_password

  # High availability
  multi_az = var.db_multi_az

  # Backups
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # Safety
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot
  apply_immediately   = false

  tags = var.tags
}

# Matching Database
module "rds_matching" {
  source = "./modules/rds"

  name_prefix          = "${var.project_name}-${var.environment}-matching"
  vpc_id               = module.vpc.vpc_id
  database_subnet_ids  = module.vpc.private_subnet_ids
  db_subnet_group_name = aws_db_subnet_group.main.name
  security_group_ids   = [module.security_groups.matching_db_security_group_id]

  # Database configuration
  engine_version        = var.db_engine_version
  db_instance_class     = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  database_names        = ["matching_db"]
  master_username       = var.db_username
  master_password       = var.db_password

  # High availability
  multi_az = var.db_multi_az

  # Backups
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # Safety
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot
  apply_immediately   = false

  tags = var.tags
}

# History Database
module "rds_history" {
  source = "./modules/rds"

  name_prefix          = "${var.project_name}-${var.environment}-history"
  vpc_id               = module.vpc.vpc_id
  database_subnet_ids  = module.vpc.private_subnet_ids
  db_subnet_group_name = aws_db_subnet_group.main.name
  security_group_ids   = [module.security_groups.history_db_security_group_id]

  # Database configuration
  engine_version        = var.db_engine_version
  db_instance_class     = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  database_names        = ["history_db"]
  master_username       = var.db_username
  master_password       = var.db_password

  # High availability
  multi_az = var.db_multi_az

  # Backups
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # Safety
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot
  apply_immediately   = false

  tags = var.tags
}

# =============================================================================
# Phase 2: ElastiCache Redis - 3 Separate Clusters
# =============================================================================
# ElastiCache Subnet Group for Redis clusters
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-subnet-group"
    }
  )
}

# Matching Redis Cluster
module "elasticache_matching" {
  source = "./modules/elasticache"

  name_prefix            = "${var.project_name}-${var.environment}-matching"
  vpc_id                 = module.vpc.vpc_id
  cache_subnet_ids       = module.vpc.private_subnet_ids
  cache_subnet_group_name = aws_elasticache_subnet_group.main.name
  security_group_ids     = [module.security_groups.matching_redis_security_group_id]

  # Redis configuration
  engine_version   = var.redis_engine_version
  node_type        = var.redis_node_type
  num_cache_nodes  = var.redis_num_cache_nodes

  # Maintenance and backups
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-04:00"
  snapshot_retention_limit = var.redis_snapshot_retention_limit

  tags = var.tags
}

# Collaboration Redis Cluster (for WebSocket sessions)
module "elasticache_collaboration" {
  source = "./modules/elasticache"

  name_prefix            = "${var.project_name}-${var.environment}-collab"
  vpc_id                 = module.vpc.vpc_id
  cache_subnet_ids       = module.vpc.private_subnet_ids
  cache_subnet_group_name = aws_elasticache_subnet_group.main.name
  security_group_ids     = [module.security_groups.collaboration_redis_security_group_id]

  # Redis configuration
  engine_version   = var.redis_engine_version
  node_type        = var.redis_node_type
  num_cache_nodes  = var.redis_num_cache_nodes

  # Maintenance and backups
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-04:00"
  snapshot_retention_limit = var.redis_snapshot_retention_limit

  tags = var.tags
}

# Chat Redis Cluster (for WebSocket sessions)
module "elasticache_chat" {
  source = "./modules/elasticache"

  name_prefix            = "${var.project_name}-${var.environment}-chat"
  vpc_id                 = module.vpc.vpc_id
  cache_subnet_ids       = module.vpc.private_subnet_ids
  cache_subnet_group_name = aws_elasticache_subnet_group.main.name
  security_group_ids     = [module.security_groups.chat_redis_security_group_id]

  # Redis configuration
  engine_version   = var.redis_engine_version
  node_type        = var.redis_node_type
  num_cache_nodes  = var.redis_num_cache_nodes

  # Maintenance and backups
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-04:00"
  snapshot_retention_limit = var.redis_snapshot_retention_limit

  tags = var.tags
}

# =============================================================================
# Phase 3: Application Load Balancer
# =============================================================================
module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id

  # Optional: Enable deletion protection in production
  enable_deletion_protection = var.alb_enable_deletion_protection

  # Optional: S3 bucket for access logs
  access_logs_bucket = var.alb_access_logs_bucket

  # Optional: ACM certificate ARN for HTTPS
  certificate_arn = var.alb_certificate_arn

  # CloudWatch alarm actions
  alarm_actions = var.alarm_actions

  tags = var.tags
}

# =============================================================================
# Phase 4: ECS Cluster
# =============================================================================
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_name = var.project_name
  environment  = var.environment

  # Enable container insights for monitoring
  enable_container_insights = var.enable_container_insights

  # CloudWatch log retention
  log_retention_days = var.ecs_log_retention_days

  tags = var.tags
}

# =============================================================================
# Phase 4: Service Discovery (AWS Cloud Map)
# =============================================================================
module "service_discovery" {
  source = "./modules/service-discovery"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  tags = var.tags
}

# =============================================================================
# Phase 4: ECR Repositories (for Docker images)
# =============================================================================
locals {
  services = {
    "frontend"              = {}
    "user-service"          = {}
    "question-service"      = {}
    "matching-service"      = {}
    "history-service"       = {}
    "collaboration-service" = {}
    "chat-service"          = {}
  }
}

resource "aws_ecr_repository" "services" {
  for_each = local.services
  force_delete = true

  name                 = "${var.project_name}-${var.environment}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.key}"
      Service = each.key
    }
  )
}

# ECR lifecycle policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "services" {
  for_each = local.services

  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# =============================================================================
# Phase 4: ECS Services with Task Definitions
# =============================================================================

# -----------------------------------------------------------------------------
# 1. User Service
# -----------------------------------------------------------------------------
module "ecs_service_user" {
  source = "./modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  service_name = "user-service"

  # ECS Configuration
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.vpc.vpc_id

  # Networking
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_security_group_id]

  # Container Configuration
  container_image  = "${aws_ecr_repository.services["user-service"].repository_url}:latest"
  container_port   = 8000
  container_cpu    = var.user_service_cpu
  container_memory = var.user_service_memory
  desired_count    = var.user_service_desired_count

  # Environment Variables
  environment_variables = {
    DEBUG        = "false"
    SECRET_KEY   = var.secret_key
    ALLOWED_HOSTS = "*"  # Allow all hosts since service is behind ALB in private VPC

    # Database Connection
    DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${module.rds_user.db_endpoint}/user_db"
    DB_HOST      = module.rds_user.db_host
    DB_PORT      = "5432"
    DB_NAME      = "user_db"
    DB_USER      = var.db_username
    DB_PASSWORD  = var.db_password

    # Service-to-Service URLs
    QUESTION_SERVICE_URL      = "http://question-service.${module.service_discovery.namespace_name}:8000"
    MATCHING_SERVICE_URL      = "http://matching-service.${module.service_discovery.namespace_name}:8000"
    HISTORY_SERVICE_URL       = "http://history-service.${module.service_discovery.namespace_name}:8000"
    COLLABORATION_SERVICE_URL = "http://collaboration-service.${module.service_discovery.namespace_name}:8000"
    CHAT_SERVICE_URL          = "http://chat-service.${module.service_discovery.namespace_name}:8000"
  }

  # IAM Roles
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.ecs_cluster.task_role_arn

  # CloudWatch Logs
  log_group_name = module.ecs_cluster.cloudwatch_log_group_name
  aws_region     = var.aws_region

  # Load Balancer
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arns["user-service"]

  # Service Discovery
  enable_service_discovery       = true
  service_discovery_service_arn  = module.service_discovery.service_discovery_services["user-service"]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# 2. Question Service
# -----------------------------------------------------------------------------
module "ecs_service_question" {
  source = "./modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  service_name = "question-service"

  # ECS Configuration
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.vpc.vpc_id

  # Networking
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_security_group_id]

  # Container Configuration
  container_image  = "${aws_ecr_repository.services["question-service"].repository_url}:latest"
  container_port   = 8000
  container_cpu    = var.question_service_cpu
  container_memory = var.question_service_memory
  desired_count    = var.question_service_desired_count

  # Environment Variables
  environment_variables = {
    DEBUG             = "false"
    SECRET_KEY        = var.secret_key
    ALLOWED_HOSTS     = "*"  # Allow all hosts since service is behind ALB in private VPC
    DJANGO_USE_SQLITE = "0"

    # Database Connection
    DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${module.rds_question.db_endpoint}/question_db"
    DB_HOST      = module.rds_question.db_host
    DB_PORT      = "5432"
    DB_NAME      = "question_db"
    DB_USER      = var.db_username
    DB_PASSWORD  = var.db_password

    # Service-to-Service URLs
    USER_SERVICE_URL     = "http://user-service.${module.service_discovery.namespace_name}:8000"
    MATCHING_SERVICE_URL = "http://matching-service.${module.service_discovery.namespace_name}:8000"
    HISTORY_SERVICE_URL  = "http://history-service.${module.service_discovery.namespace_name}:8000"
  }

  # IAM Roles
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.ecs_cluster.task_role_arn

  # CloudWatch Logs
  log_group_name = module.ecs_cluster.cloudwatch_log_group_name
  aws_region     = var.aws_region

  # Load Balancer
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arns["question-service"]

  # Service Discovery
  enable_service_discovery      = true
  service_discovery_service_arn = module.service_discovery.service_discovery_services["question-service"]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# 3. Matching Service
# -----------------------------------------------------------------------------
module "ecs_service_matching" {
  source = "./modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  service_name = "matching-service"

  # ECS Configuration
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.vpc.vpc_id

  # Networking
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_security_group_id]

  # Container Configuration
  container_image  = "${aws_ecr_repository.services["matching-service"].repository_url}:latest"
  container_port   = 8000
  container_cpu    = var.matching_service_cpu
  container_memory = var.matching_service_memory
  desired_count    = var.matching_service_desired_count

  # Environment Variables
  environment_variables = {
    DEBUG         = "false"
    ALLOWED_HOSTS = "*"  # Allow all hosts since service is behind ALB in private VPC

    # Database Connection
    DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${module.rds_matching.db_endpoint}/matching_db"
    DB_HOST      = module.rds_matching.db_host
    DB_PORT      = "5432"
    DB_NAME      = "matching_db"
    DB_USER      = var.db_username
    DB_PASSWORD  = var.db_password

    # Redis Connection
    REDIS_URL  = "redis://${module.elasticache_matching.redis_endpoint}:6379/0"
    REDIS_HOST = module.elasticache_matching.redis_endpoint
    REDIS_PORT = "6379"

    # Service-to-Service URLs
    USER_SERVICE_URL     = "http://user-service.${module.service_discovery.namespace_name}:8000"
    QUESTION_SERVICE_URL = "http://question-service.${module.service_discovery.namespace_name}:8000"
  }

  # IAM Roles
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.ecs_cluster.task_role_arn

  # CloudWatch Logs
  log_group_name = module.ecs_cluster.cloudwatch_log_group_name
  aws_region     = var.aws_region

  # Load Balancer
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arns["matching-service"]

  # Service Discovery
  enable_service_discovery      = true
  service_discovery_service_arn = module.service_discovery.service_discovery_services["matching-service"]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# 4. History Service
# -----------------------------------------------------------------------------
module "ecs_service_history" {
  source = "./modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  service_name = "history-service"

  # ECS Configuration
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.vpc.vpc_id

  # Networking
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_security_group_id]

  # Container Configuration
  container_image  = "${aws_ecr_repository.services["history-service"].repository_url}:latest"
  container_port   = 8000
  container_cpu    = var.history_service_cpu
  container_memory = var.history_service_memory
  desired_count    = var.history_service_desired_count

  # Environment Variables
  environment_variables = {
    DEBUG         = "false"
    SECRET_KEY    = var.secret_key
    ALLOWED_HOSTS = "*"  # Allow all hosts since service is behind ALB in private VPC

    # Database Connection
    DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${module.rds_history.db_endpoint}/history_db"
    DB_HOST      = module.rds_history.db_host
    DB_PORT      = "5432"
    DB_NAME      = "history_db"
    DB_USER      = var.db_username
    DB_PASSWORD  = var.db_password

    # Service-to-Service URLs
    USER_SERVICE_URL          = "http://user-service.${module.service_discovery.namespace_name}:8000"
    QUESTION_SERVICE_URL      = "http://question-service.${module.service_discovery.namespace_name}:8000"
    COLLABORATION_SERVICE_URL = "http://collaboration-service.${module.service_discovery.namespace_name}:8000"
  }

  # IAM Roles
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.ecs_cluster.task_role_arn

  # CloudWatch Logs
  log_group_name = module.ecs_cluster.cloudwatch_log_group_name
  aws_region     = var.aws_region

  # Load Balancer
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arns["history-service"]

  # Service Discovery
  enable_service_discovery      = true
  service_discovery_service_arn = module.service_discovery.service_discovery_services["history-service"]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# 5. Collaboration Service (WebSocket)
# -----------------------------------------------------------------------------
module "ecs_service_collaboration" {
  source = "./modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  service_name = "collaboration-service"

  # ECS Configuration
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.vpc.vpc_id

  # Networking
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_security_group_id]

  # Container Configuration
  container_image  = "${aws_ecr_repository.services["collaboration-service"].repository_url}:latest"
  container_port   = 8000
  container_cpu    = var.collaboration_service_cpu
  container_memory = var.collaboration_service_memory
  desired_count    = var.collaboration_service_desired_count

  # Environment Variables
  environment_variables = {
    DEBUG = "false"
    PORT  = "8000"
    SERVICE_PREFIX = "/collaboration-service-api"

    # Redis Connection (for WebSocket session management)
    REDIS_URL  = "redis://${module.elasticache_collaboration.redis_endpoint}:6379/0"
    REDIS_HOST = module.elasticache_collaboration.redis_endpoint
    REDIS_PORT = "6379"

    # Service-to-Service URLs
    USER_SERVICE_URL     = "http://user-service.${module.service_discovery.namespace_name}:8000"
    QUESTION_SERVICE_URL = "http://question-service.${module.service_discovery.namespace_name}:8000"
    CHAT_SERVICE_URL     = "http://chat-service.${module.service_discovery.namespace_name}:8000"
  }

  # IAM Roles
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.ecs_cluster.task_role_arn

  # CloudWatch Logs
  log_group_name = module.ecs_cluster.cloudwatch_log_group_name
  aws_region     = var.aws_region

  # Load Balancer (with sticky sessions for WebSocket)
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arns["collaboration-service"]

  # Service Discovery
  enable_service_discovery      = true
  service_discovery_service_arn = module.service_discovery.service_discovery_services["collaboration-service"]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# 6. Chat Service (WebSocket)
# -----------------------------------------------------------------------------
module "ecs_service_chat" {
  source = "./modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  service_name = "chat-service"

  # ECS Configuration
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.vpc.vpc_id

  # Networking
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_security_group_id]

  # Container Configuration
  container_image  = "${aws_ecr_repository.services["chat-service"].repository_url}:latest"
  container_port   = 8000
  container_cpu    = var.chat_service_cpu
  container_memory = var.chat_service_memory
  desired_count    = var.chat_service_desired_count

  # Environment Variables
  environment_variables = {
    DEBUG = "false"
    PORT  = "8000"
    SERVICE_PREFIX = "/chat-service-api"

    # Redis Connection (for WebSocket session management)
    REDIS_URL  = "redis://${module.elasticache_chat.redis_endpoint}:6379/0"
    REDIS_HOST = module.elasticache_chat.redis_endpoint
    REDIS_PORT = "6379"

    # Service-to-Service URLs
    USER_SERVICE_URL          = "http://user-service.${module.service_discovery.namespace_name}:8000"
    COLLABORATION_SERVICE_URL = "http://collaboration-service.${module.service_discovery.namespace_name}:8000"
  }

  # IAM Roles
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.ecs_cluster.task_role_arn

  # CloudWatch Logs
  log_group_name = module.ecs_cluster.cloudwatch_log_group_name
  aws_region     = var.aws_region

  # Load Balancer (with sticky sessions for WebSocket)
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arns["chat-service"]

  # Service Discovery
  enable_service_discovery      = true
  service_discovery_service_arn = module.service_discovery.service_discovery_services["chat-service"]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# 7. Frontend (React + Nginx)
# -----------------------------------------------------------------------------
module "ecs_service_frontend" {
  source = "./modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  service_name = "frontend"

  # ECS Configuration
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.vpc.vpc_id

  # Networking
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.ecs_security_group_id]

  # Container Configuration
  container_image  = "${aws_ecr_repository.services["frontend"].repository_url}:latest"
  container_port   = 80
  container_cpu    = var.frontend_cpu
  container_memory = var.frontend_memory
  desired_count    = var.frontend_desired_count

  # Environment Variables
  environment_variables = {
    NODE_ENV = "production"

    # Nginx proxy configuration (service hostnames for proxy_pass)
    NGINX_USER_SERVICE_HOST          = "user-service.${module.service_discovery.namespace_name}"
    NGINX_QUESTION_SERVICE_HOST      = "question-service.${module.service_discovery.namespace_name}"
    NGINX_MATCHING_SERVICE_HOST      = "matching-service.${module.service_discovery.namespace_name}"
    NGINX_HISTORY_SERVICE_HOST       = "history-service.${module.service_discovery.namespace_name}"
    NGINX_SESSION_SERVICE_HOST       = "session-service.${module.service_discovery.namespace_name}"
    NGINX_COLLABORATION_SERVICE_HOST = "collaboration-service.${module.service_discovery.namespace_name}"
    NGINX_CHAT_SERVICE_HOST          = "chat-service.${module.service_discovery.namespace_name}"

    # VITE build-time variables (embedded in JS bundle)
    VITE_QUESTION_SERVICE_URL      = "/question-service-api"
    VITE_MATCHING_SERVICE_URL      = "/matching-service-api"
    VITE_HISTORY_SERVICE_URL       = "/history-service-api"
    VITE_USER_SERVICE_URL          = "/user-service-api"
    VITE_SESSION_SERVICE_URL       = "/session-service-api"
    VITE_COLLABORATION_SERVICE_URL = "/collaboration-service-api"
    VITE_CHAT_SERVICE_URL          = "/chat-service-api"
  }

  # IAM Roles
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.ecs_cluster.task_role_arn

  # CloudWatch Logs
  log_group_name = module.ecs_cluster.cloudwatch_log_group_name
  aws_region     = var.aws_region

  # Load Balancer
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arns["frontend"]

  # No service discovery for frontend (public-facing only)
  enable_service_discovery = false

  tags = var.tags
}

# =============================================================================
# Phase 5: Auto-Scaling Configuration
# =============================================================================
# Application Auto Scaling targets and policies for each ECS service

locals {
  autoscaling_services = {
    "user-service" = {
      service_name      = module.ecs_service_user.service_name
      min_capacity      = var.ecs_min_capacity
      max_capacity      = var.ecs_max_capacity
      cpu_target        = var.autoscaling_cpu_target
      memory_target     = var.autoscaling_memory_target
    }
    "question-service" = {
      service_name      = module.ecs_service_question.service_name
      min_capacity      = var.ecs_min_capacity
      max_capacity      = var.ecs_max_capacity
      cpu_target        = var.autoscaling_cpu_target
      memory_target     = var.autoscaling_memory_target
    }
    "matching-service" = {
      service_name      = module.ecs_service_matching.service_name
      min_capacity      = var.ecs_min_capacity
      max_capacity      = var.ecs_max_capacity
      cpu_target        = var.autoscaling_cpu_target
      memory_target     = var.autoscaling_memory_target
    }
    "history-service" = {
      service_name      = module.ecs_service_history.service_name
      min_capacity      = var.ecs_min_capacity
      max_capacity      = var.ecs_max_capacity
      cpu_target        = var.autoscaling_cpu_target
      memory_target     = var.autoscaling_memory_target
    }
    "collaboration-service" = {
      service_name      = module.ecs_service_collaboration.service_name
      min_capacity      = var.ecs_min_capacity
      max_capacity      = var.ecs_max_capacity
      cpu_target        = var.autoscaling_cpu_target
      memory_target     = var.autoscaling_memory_target
    }
    "chat-service" = {
      service_name      = module.ecs_service_chat.service_name
      min_capacity      = var.ecs_min_capacity
      max_capacity      = var.ecs_max_capacity
      cpu_target        = var.autoscaling_cpu_target
      memory_target     = var.autoscaling_memory_target
    }
    "frontend" = {
      service_name      = module.ecs_service_frontend.service_name
      min_capacity      = var.ecs_min_capacity
      max_capacity      = var.ecs_max_capacity
      cpu_target        = var.autoscaling_cpu_target
      memory_target     = var.autoscaling_memory_target
    }
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Targets
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_target" "ecs_services" {
  for_each = local.autoscaling_services

  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${module.ecs_cluster.cluster_name}/${each.value.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# -----------------------------------------------------------------------------
# CPU-based Auto Scaling Policy
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  for_each = local.autoscaling_services

  name               = "${var.project_name}-${var.environment}-${each.key}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = each.value.cpu_target
    scale_in_cooldown  = 300  # 5 minutes
    scale_out_cooldown = 60   # 1 minute
  }
}

# -----------------------------------------------------------------------------
# Memory-based Auto Scaling Policy
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  for_each = local.autoscaling_services

  name               = "${var.project_name}-${var.environment}-${each.key}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = each.value.memory_target
    scale_in_cooldown  = 300  # 5 minutes
    scale_out_cooldown = 60   # 1 minute
  }
}

# -----------------------------------------------------------------------------
# ALB Request Count-based Auto Scaling Policy (for frontend and backend services)
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_policy" "ecs_requests_policy" {
  for_each = local.autoscaling_services

  name               = "${var.project_name}-${var.environment}-${each.key}-requests-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${module.alb.alb_arn_suffix}/${module.alb.target_group_arn_suffixes[each.key]}"
    }

    target_value       = var.autoscaling_requests_target
    scale_in_cooldown  = 300  # 5 minutes
    scale_out_cooldown = 60   # 1 minute
  }
}
