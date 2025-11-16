# =============================================================================
# Service Discovery Module Outputs
# =============================================================================

output "namespace_id" {
  description = "ID of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "namespace_name" {
  description = "Name of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "namespace_arn" {
  description = "ARN of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "service_discovery_services" {
  description = "Map of service discovery service ARNs"
  value       = { for k, v in aws_service_discovery_service.services : k => v.arn }
}

output "service_dns_names" {
  description = "Map of service DNS names"
  value       = { for k, v in aws_service_discovery_service.services : k => "${v.name}.${aws_service_discovery_private_dns_namespace.main.name}" }
}
