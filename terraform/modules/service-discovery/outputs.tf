# =============================================================================
# Service Discovery Module - Outputs
# =============================================================================

output "namespace_id" {
  description = "ID of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "namespace_name" {
  description = "Name of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "namespace_arn" {
  description = "ARN of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "namespace_hosted_zone" {
  description = "Hosted zone ID of the namespace"
  value       = aws_service_discovery_private_dns_namespace.main.hosted_zone
}

output "service_discovery_services" {
  description = "Map of service discovery service ARNs"
  value = {
    for service, svc in aws_service_discovery_service.services : service => svc.arn
  }
}

output "service_discovery_service_ids" {
  description = "Map of service discovery service IDs"
  value = {
    for service, svc in aws_service_discovery_service.services : service => svc.id
  }
}

output "service_dns_names" {
  description = "DNS names for service-to-service communication"
  value = {
    for service in local.backend_services : service => "${service}.${aws_service_discovery_private_dns_namespace.main.name}"
  }
}
