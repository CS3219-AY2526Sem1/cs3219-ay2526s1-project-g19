# =============================================================================
# EFS Module - Outputs
# =============================================================================

output "file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.main.id
}

output "file_system_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.main.arn
}

output "file_system_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.main.dns_name
}

output "mount_target_ids" {
  description = "IDs of the EFS mount targets"
  value       = aws_efs_mount_target.main[*].id
}

output "access_point_id" {
  description = "ID of the EFS access point"
  value       = var.create_access_point ? aws_efs_access_point.main[0].id : null
}

output "access_point_arn" {
  description = "ARN of the EFS access point"
  value       = var.create_access_point ? aws_efs_access_point.main[0].arn : null
}
