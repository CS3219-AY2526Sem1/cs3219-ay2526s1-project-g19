# =============================================================================
# ALB Module - Outputs
# =============================================================================

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for CloudWatch metrics)"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arns" {
  description = "Map of service names to target group ARNs"
  value = {
    for service, tg in aws_lb_target_group.services : service => tg.arn
  }
}

output "target_group_arn_suffixes" {
  description = "Map of service names to target group ARN suffixes"
  value = {
    for service, tg in aws_lb_target_group.services : service => tg.arn_suffix
  }
}

output "target_group_names" {
  description = "Map of service names to target group names"
  value = {
    for service, tg in aws_lb_target_group.services : service => tg.name
  }
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "alb_url" {
  description = "Full HTTP URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "service_urls" {
  description = "URLs for each service through the ALB"
  value = {
    frontend              = "http://${aws_lb.main.dns_name}/"
    user_service          = "http://${aws_lb.main.dns_name}/user-service-api/"
    question_service      = "http://${aws_lb.main.dns_name}/question-service-api/"
    matching_service      = "http://${aws_lb.main.dns_name}/matching-service-api/"
    history_service       = "http://${aws_lb.main.dns_name}/history-service-api/"
    collaboration_service = "http://${aws_lb.main.dns_name}/collaboration-service-api/"
    chat_service          = "http://${aws_lb.main.dns_name}/chat-service-api/"
  }
}
