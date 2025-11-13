# =============================================================================
# Security Groups Module - Outputs
# =============================================================================

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs.id
}

output "db_security_group_ids" {
  description = "Map of database security group IDs (user, question, matching, history)"
  value = {
    for name, sg in aws_security_group.db : name => sg.id
  }
}

output "redis_security_group_ids" {
  description = "Map of Redis security group IDs (matching, collaboration, chat)"
  value = {
    for name, sg in aws_security_group.redis : name => sg.id
  }
}

# Individual outputs for easier reference
output "user_db_security_group_id" {
  description = "Security group ID for user database"
  value       = aws_security_group.db["user"].id
}

output "question_db_security_group_id" {
  description = "Security group ID for question database"
  value       = aws_security_group.db["question"].id
}

output "matching_db_security_group_id" {
  description = "Security group ID for matching database"
  value       = aws_security_group.db["matching"].id
}

output "history_db_security_group_id" {
  description = "Security group ID for history database"
  value       = aws_security_group.db["history"].id
}

output "matching_redis_security_group_id" {
  description = "Security group ID for matching Redis"
  value       = aws_security_group.redis["matching"].id
}

output "collaboration_redis_security_group_id" {
  description = "Security group ID for collaboration Redis"
  value       = aws_security_group.redis["collaboration"].id
}

output "chat_redis_security_group_id" {
  description = "Security group ID for chat Redis"
  value       = aws_security_group.redis["chat"].id
}
