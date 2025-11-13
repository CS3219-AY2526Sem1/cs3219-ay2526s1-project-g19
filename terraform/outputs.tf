# =============================================================================
# PeerPrep AWS ECS Infrastructure - Outputs
# =============================================================================
# Key information to use after infrastructure is created
# Access with: terraform output <output_name>
# =============================================================================

# -----------------------------------------------------------------------------
# Phase 1: VPC and Networking Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

# -----------------------------------------------------------------------------
# Phase 1: Security Group Outputs
# -----------------------------------------------------------------------------
output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = module.security_groups.ecs_security_group_id
}

output "db_security_group_ids" {
  description = "Map of database security group IDs"
  value       = module.security_groups.db_security_group_ids
}

output "redis_security_group_ids" {
  description = "Map of Redis security group IDs"
  value       = module.security_groups.redis_security_group_ids
}

# -----------------------------------------------------------------------------
# Phase 2: RDS Outputs
# -----------------------------------------------------------------------------
output "rds_user_endpoint" {
  description = "User database endpoint"
  value       = module.rds_user.db_endpoint
  sensitive   = true
}

output "rds_question_endpoint" {
  description = "Question database endpoint"
  value       = module.rds_question.db_endpoint
  sensitive   = true
}

output "rds_matching_endpoint" {
  description = "Matching database endpoint"
  value       = module.rds_matching.db_endpoint
  sensitive   = true
}

output "rds_history_endpoint" {
  description = "History database endpoint"
  value       = module.rds_history.db_endpoint
  sensitive   = true
}

output "rds_connection_strings" {
  description = "Database connection strings for services"
  value = {
    user_db     = "postgresql://${var.db_username}:****@${module.rds_user.db_host}:${module.rds_user.db_port}/user_db"
    question_db = "postgresql://${var.db_username}:****@${module.rds_question.db_host}:${module.rds_question.db_port}/question_db"
    matching_db = "postgresql://${var.db_username}:****@${module.rds_matching.db_host}:${module.rds_matching.db_port}/matching_db"
    history_db  = "postgresql://${var.db_username}:****@${module.rds_history.db_host}:${module.rds_history.db_port}/history_db"
  }
  sensitive = true
}

# -----------------------------------------------------------------------------
# Phase 2: ElastiCache Outputs
# -----------------------------------------------------------------------------
output "redis_matching_endpoint" {
  description = "Matching Redis endpoint"
  value       = module.elasticache_matching.redis_endpoint
  sensitive   = true
}

output "redis_collaboration_endpoint" {
  description = "Collaboration Redis endpoint"
  value       = module.elasticache_collaboration.redis_endpoint
  sensitive   = true
}

output "redis_chat_endpoint" {
  description = "Chat Redis endpoint"
  value       = module.elasticache_chat.redis_endpoint
  sensitive   = true
}

output "redis_connection_strings" {
  description = "Redis connection strings for services"
  value = {
    matching      = "redis://${module.elasticache_matching.redis_endpoint}:${module.elasticache_matching.redis_port}/0"
    collaboration = "redis://${module.elasticache_collaboration.redis_endpoint}:${module.elasticache_collaboration.redis_port}/0"
    chat          = "redis://${module.elasticache_chat.redis_endpoint}:${module.elasticache_chat.redis_port}/0"
  }
  sensitive = true
}

# -----------------------------------------------------------------------------
# Phase 3: ALB Outputs
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "alb_url" {
  description = "Full HTTP URL to access the application"
  value       = module.alb.alb_url
}

output "alb_target_group_arns" {
  description = "Map of target group ARNs for ECS services"
  value       = module.alb.target_group_arns
}

output "service_urls" {
  description = "URLs for each service through the ALB"
  value       = module.alb.service_urls
}

# -----------------------------------------------------------------------------
# Phase 4: ECS Cluster Outputs
# -----------------------------------------------------------------------------
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.cluster_arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.ecs_cluster.task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.ecs_cluster.task_role_arn
}

output "ecs_log_group_name" {
  description = "Name of the CloudWatch log group for ECS"
  value       = module.ecs_cluster.cloudwatch_log_group_name
}

# -----------------------------------------------------------------------------
# Phase 4: Service Discovery Outputs
# -----------------------------------------------------------------------------
output "service_discovery_namespace_id" {
  description = "ID of the Cloud Map namespace"
  value       = module.service_discovery.namespace_id
}

output "service_discovery_namespace_name" {
  description = "Name of the Cloud Map namespace"
  value       = module.service_discovery.namespace_name
}

output "service_discovery_dns_names" {
  description = "DNS names for service-to-service communication"
  value       = module.service_discovery.service_dns_names
}

# -----------------------------------------------------------------------------
# Phase 4: ECR Repository Outputs
# -----------------------------------------------------------------------------
output "ecr_repository_urls" {
  description = "Map of ECR repository URLs for pushing Docker images"
  value = {
    for name, repo in aws_ecr_repository.services : name => repo.repository_url
  }
}

# -----------------------------------------------------------------------------
# Phase 4: ECS Service Outputs
# -----------------------------------------------------------------------------
output "ecs_service_names" {
  description = "Names of all ECS services"
  value = {
    user          = module.ecs_service_user.service_name
    question      = module.ecs_service_question.service_name
    matching      = module.ecs_service_matching.service_name
    history       = module.ecs_service_history.service_name
    collaboration = module.ecs_service_collaboration.service_name
    chat          = module.ecs_service_chat.service_name
    frontend      = module.ecs_service_frontend.service_name
  }
}

output "ecs_service_arns" {
  description = "ARNs of all ECS services"
  value = {
    user          = module.ecs_service_user.service_arn
    question      = module.ecs_service_question.service_arn
    matching      = module.ecs_service_matching.service_arn
    history       = module.ecs_service_history.service_arn
    collaboration = module.ecs_service_collaboration.service_arn
    chat          = module.ecs_service_chat.service_arn
    frontend      = module.ecs_service_frontend.service_arn
  }
}

output "ecs_task_definition_arns" {
  description = "ARNs of all ECS task definitions"
  value = {
    user          = module.ecs_service_user.task_definition_arn
    question      = module.ecs_service_question.task_definition_arn
    matching      = module.ecs_service_matching.task_definition_arn
    history       = module.ecs_service_history.task_definition_arn
    collaboration = module.ecs_service_collaboration.task_definition_arn
    chat          = module.ecs_service_chat.task_definition_arn
    frontend      = module.ecs_service_frontend.task_definition_arn
  }
}

# -----------------------------------------------------------------------------
# Summary Output (for quick reference)
# -----------------------------------------------------------------------------
output "deployment_summary" {
  description = "Complete deployment summary with connection information"
  value = {
    # Application Access
    application_url = module.alb.alb_url
    alb_dns_name    = module.alb.alb_dns_name

    # Service Endpoints
    service_endpoints = {
      frontend      = "${module.alb.alb_url}/"
      user          = "${module.alb.alb_url}/user-service-api"
      question      = "${module.alb.alb_url}/question-service-api"
      matching      = "${module.alb.alb_url}/matching-service-api"
      history       = "${module.alb.alb_url}/history-service-api"
      collaboration = "${module.alb.alb_url}/collaboration-service-api"
      chat          = "${module.alb.alb_url}/chat-service-api"
    }

    # Infrastructure
    vpc_id               = module.vpc.vpc_id
    ecs_cluster_name     = module.ecs_cluster.cluster_name
    service_discovery    = module.service_discovery.namespace_name

    # Resources Created
    resources = {
      rds_instances       = 4
      redis_clusters      = 3
      ecs_services        = 7
      ecr_repositories    = 7
      availability_zones  = 2
      nat_gateways       = 1
    }

    # Next Steps
    next_steps = [
      "1. Build and push Docker images to ECR repositories",
      "2. Run database migrations for each service",
      "3. Verify services are healthy: terraform output ecs_service_names",
      "4. Check CloudWatch logs: /ecs/peerprep-prod/<service-name>",
      "5. Access application at the application_url above"
    ]
  }
}

output "ecr_push_commands" {
  description = "Commands to push Docker images to ECR"
  value = {
    for name, repo in aws_ecr_repository.services : name => {
      login   = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", repo.repository_url)[0]}"
      build   = "docker build -t ${name} ./<path-to-${name}>"
      tag     = "docker tag ${name}:latest ${repo.repository_url}:latest"
      push    = "docker push ${repo.repository_url}:latest"
    }
  }
}
