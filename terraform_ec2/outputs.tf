# =============================================================================
# PeerPrep EC2 Deployment - Outputs
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.peerprep.id
}

output "instance_public_ip" {
  description = "Elastic IP address (use this to access your application)"
  value       = var.elastic_ip_allocation_id != "" ? data.aws_eip.existing[0].public_ip : aws_eip.peerprep[0].public_ip
}

output "instance_private_ip" {
  description = "Private IP address"
  value       = aws_instance.peerprep.private_ip
}

output "instance_type" {
  description = "EC2 instance type"
  value       = aws_instance.peerprep.instance_type
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.peerprep.id
}

output "application_url" {
  description = "URL to access the PeerPrep application"
  value       = "http://${var.elastic_ip_allocation_id != "" ? data.aws_eip.existing[0].public_ip : aws_eip.peerprep[0].public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance (if key_name is configured)"
  value       = var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${var.elastic_ip_allocation_id != "" ? data.aws_eip.existing[0].public_ip : aws_eip.peerprep[0].public_ip}" : "SSH not configured (use AWS Systems Manager Session Manager instead)"
}

output "ssm_session_command" {
  description = "AWS Systems Manager Session Manager command (no SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.peerprep.id} --region ${var.aws_region}"
}

output "deployment_status_command" {
  description = "Command to check deployment logs"
  value       = "ssh ubuntu@${var.elastic_ip_allocation_id != "" ? data.aws_eip.existing[0].public_ip : aws_eip.peerprep[0].public_ip} 'tail -f /var/log/cloud-init-output.log'"
}

output "docker_status_command" {
  description = "Command to check Docker container status"
  value       = "ssh ubuntu@${var.elastic_ip_allocation_id != "" ? data.aws_eip.existing[0].public_ip : aws_eip.peerprep[0].public_ip} 'cd /opt/peerprep && docker compose ps'"
}

output "key_name" {
  description = "EC2 key pair name (if configured)"
  value       = var.key_name
}
