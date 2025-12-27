# =============================================================================
# ECS Service Module - Variables
# =============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "service_name" {
  description = "Name of the service (e.g., user-service, frontend)"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for ECS tasks"
  type        = list(string)
}

# Container Configuration
variable "container_image" {
  description = "Docker image for the container"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "container_cpu" {
  description = "CPU units for the container (1 vCPU = 1024)"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory for the container in MB"
  type        = number
  default     = 512
}

variable "container_health_check_path" {
  description = "HTTP path the container health check should query (must include leading /)"
  type        = string
  default     = "/health"
}

variable "container_health_check_command" {
  description = "Override for the container health check command (leave empty to use default HTTP check)"
  type        = list(string)
  default     = []
}

variable "container_health_check_interval" {
  description = "Interval between health checks"
  type        = number
  default     = 30
}

variable "container_health_check_timeout" {
  description = "Timeout for health checks"
  type        = number
  default     = 5
}

variable "container_health_check_retries" {
  description = "Consecutive failures before marking unhealthy"
  type        = number
  default     = 3
}

variable "container_health_check_start_period" {
  description = "Grace period before starting health checks"
  type        = number
  default     = 60
}

# Environment Variables
variable "environment_variables" {
  description = "Map of environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "List of secrets from AWS Secrets Manager or SSM Parameter Store"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

# Service Configuration
variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "enable_service_discovery" {
  description = "Enable service discovery registration"
  type        = bool
  default     = false
}

variable "service_discovery_service_arn" {
  description = "Service discovery service ARN"
  type        = string
  default     = ""
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
  default     = ""
}

variable "enable_load_balancer" {
  description = "Enable load balancer integration"
  type        = bool
  default     = false
}

# IAM Roles
variable "task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role ARN for ECS task runtime"
  type        = string
}

# CloudWatch Logs
variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region for logging"
  type        = string
}

# Health Check
variable "health_check_grace_period_seconds" {
  description = "Grace period for health checks"
  type        = number
  default     = 60
}

# Deployment
variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percent during deployment"
  type        = number
  default     = 50
}

variable "deployment_maximum_percent" {
  description = "Maximum percent during deployment"
  type        = number
  default     = 200
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "use_capacity_providers" {
  description = "Whether to use ECS capacity providers instead of launch_type"
  type        = bool
  default     = true
}

# EFS Volume Configuration
variable "efs_volume_configuration" {
  description = "EFS volume configuration for persistent storage"
  type = object({
    name                    = string
    file_system_id          = string
    root_directory          = string
    container_path          = string
    transit_encryption      = string
    transit_encryption_port = number
    access_point_id         = string
    iam                     = string
  })
  default = null
}

variable "stop_timeout" {
  description = "Time to wait for container to stop gracefully before force killing (seconds)"
  type        = number
  default     = 30
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}
