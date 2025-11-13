# =============================================================================
# PeerPrep AWS ECS Infrastructure - Variables
# =============================================================================
# All configurable parameters for the infrastructure
# Override these values in terraform.tfvars
# =============================================================================

# -----------------------------------------------------------------------------
# Global Settings
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "peerprep"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# VPC and Networking Configuration
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (must match number of AZs)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (must match number of AZs)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost savings)"
  type        = bool
  default     = true # Set to false for high availability (one NAT per AZ)
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL Configuration (Phase 2)
# -----------------------------------------------------------------------------
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro" # Eligible for free tier
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false  # Set to true in production
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying (set to false in production)"
  type        = bool
  default     = true  # Set to false in production to keep final snapshot
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "peerprep"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "peerprep_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
  default     = "" # Must be set in terraform.tfvars or via environment variable
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ElastiCache Redis Configuration (Phase 2)
# -----------------------------------------------------------------------------
variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes (use 2+ for high availability)"
  type        = number
  default     = 2
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_snapshot_retention_limit" {
  description = "Snapshot retention limit in days"
  type        = number
  default     = 5
}

# -----------------------------------------------------------------------------
# ALB Configuration (Phase 3)
# -----------------------------------------------------------------------------
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false  # Set to true in production
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs (optional)"
  type        = string
  default     = ""
}

variable "alb_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "alarm_actions" {
  description = "List of ARNs for CloudWatch alarm actions (SNS topics)"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# ECS Service Configuration (Phase 4)
# -----------------------------------------------------------------------------
variable "service_names" {
  description = "List of microservice names"
  type        = list(string)
  default = [
    "user-service",
    "question-service",
    "matching-service",
    "history-service",
    "collaboration-service",
    "chat-service",
    "frontend"
  ]
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks in MB"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Desired number of tasks per service"
  type        = number
  default     = 2
}

variable "ecs_min_capacity" {
  description = "Minimum number of tasks for auto-scaling"
  type        = number
  default     = 2
}

variable "ecs_max_capacity" {
  description = "Maximum number of tasks for auto-scaling"
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# Container Image Configuration (Phase 4)
# -----------------------------------------------------------------------------
variable "container_images" {
  description = "Map of service names to container image URIs"
  type        = map(string)
  default     = {}
  # Example:
  # {
  #   "user-service" = "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/peerprep-user-service:latest"
  #   "question-service" = "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/peerprep-question-service:latest"
  # }
}

# -----------------------------------------------------------------------------
# Auto-scaling Configuration (Phase 6)
# -----------------------------------------------------------------------------
variable "autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization percentage for auto-scaling"
  type        = number
  default     = 80
}

variable "autoscaling_requests_target" {
  description = "Target request count per container for auto-scaling"
  type        = number
  default     = 1000
}

# -----------------------------------------------------------------------------
# Individual Service Configuration (Phase 4)
# -----------------------------------------------------------------------------
# Secret Key for Django/FastAPI services
variable "secret_key" {
  description = "Secret key for Django/FastAPI applications"
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_SECURE_SECRET_KEY_HERE"
}

# User Service
variable "user_service_cpu" {
  description = "CPU units for user service (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "user_service_memory" {
  description = "Memory for user service in MB"
  type        = number
  default     = 1024
}

variable "user_service_desired_count" {
  description = "Desired number of user service tasks"
  type        = number
  default     = 2
}

# Question Service
variable "question_service_cpu" {
  description = "CPU units for question service"
  type        = number
  default     = 512
}

variable "question_service_memory" {
  description = "Memory for question service in MB"
  type        = number
  default     = 1024
}

variable "question_service_desired_count" {
  description = "Desired number of question service tasks"
  type        = number
  default     = 2
}

# Matching Service
variable "matching_service_cpu" {
  description = "CPU units for matching service"
  type        = number
  default     = 512
}

variable "matching_service_memory" {
  description = "Memory for matching service in MB"
  type        = number
  default     = 1024
}

variable "matching_service_desired_count" {
  description = "Desired number of matching service tasks"
  type        = number
  default     = 2
}

# History Service
variable "history_service_cpu" {
  description = "CPU units for history service"
  type        = number
  default     = 256
}

variable "history_service_memory" {
  description = "Memory for history service in MB"
  type        = number
  default     = 512
}

variable "history_service_desired_count" {
  description = "Desired number of history service tasks"
  type        = number
  default     = 2
}

# Collaboration Service
variable "collaboration_service_cpu" {
  description = "CPU units for collaboration service"
  type        = number
  default     = 512
}

variable "collaboration_service_memory" {
  description = "Memory for collaboration service in MB"
  type        = number
  default     = 1024
}

variable "collaboration_service_desired_count" {
  description = "Desired number of collaboration service tasks"
  type        = number
  default     = 2
}

# Chat Service
variable "chat_service_cpu" {
  description = "CPU units for chat service"
  type        = number
  default     = 256
}

variable "chat_service_memory" {
  description = "Memory for chat service in MB"
  type        = number
  default     = 512
}

variable "chat_service_desired_count" {
  description = "Desired number of chat service tasks"
  type        = number
  default     = 2
}

# Frontend
variable "frontend_cpu" {
  description = "CPU units for frontend"
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Memory for frontend in MB"
  type        = number
  default     = 512
}

variable "frontend_desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2
}

# ECS Cluster Configuration
variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS cluster"
  type        = bool
  default     = true
}

variable "ecs_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}
