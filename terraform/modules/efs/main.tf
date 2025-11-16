# =============================================================================
# EFS (Elastic File System) Module
# =============================================================================
# Creates EFS file system with mount targets in multiple availability zones
# for persistent storage across ECS tasks
# =============================================================================

# =============================================================================
# EFS File System
# =============================================================================
resource "aws_efs_file_system" "main" {
  creation_token = "${var.project_name}-${var.environment}-${var.name}"
  encrypted      = var.encrypted
  kms_key_id     = var.kms_key_id

  performance_mode                = var.performance_mode
  throughput_mode                 = var.throughput_mode
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }

  # Explicitly set empty tags to avoid IAM permission issues
  tags = {}

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# =============================================================================
# EFS Mount Targets (one per subnet/AZ)
# =============================================================================
resource "aws_efs_mount_target" "main" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.security_group_ids

  depends_on = [aws_efs_file_system.main]
}

# =============================================================================
# EFS Access Point (optional - for better access control)
# =============================================================================
resource "aws_efs_access_point" "main" {
  count = var.create_access_point ? 1 : 0

  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = var.posix_user_gid
    uid = var.posix_user_uid
  }

  root_directory {
    path = var.root_directory_path
    creation_info {
      owner_gid   = var.posix_user_gid
      owner_uid   = var.posix_user_uid
      permissions = var.root_directory_permissions
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.name}-ap"
    }
  )
}
