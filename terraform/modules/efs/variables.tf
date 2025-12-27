# =============================================================================
# EFS Module - Variables
# =============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "name" {
  description = "Name of the EFS file system (e.g., kafka-data)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EFS mount targets"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for EFS mount targets"
  type        = list(string)
}

variable "encrypted" {
  description = "Whether to encrypt the EFS file system"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (optional)"
  type        = string
  default     = null
}

variable "performance_mode" {
  description = "Performance mode (generalPurpose or maxIO)"
  type        = string
  default     = "generalPurpose"
}

variable "throughput_mode" {
  description = "Throughput mode (bursting or provisioned)"
  type        = string
  default     = "bursting"
}

variable "provisioned_throughput_in_mibps" {
  description = "Provisioned throughput in MiB/s (only for provisioned mode)"
  type        = number
  default     = null
}

variable "transition_to_ia" {
  description = "Transition to Infrequent Access storage class (AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS)"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "create_access_point" {
  description = "Whether to create an EFS access point"
  type        = bool
  default     = true
}

variable "posix_user_uid" {
  description = "POSIX user ID for access point"
  type        = number
  default     = 1000
}

variable "posix_user_gid" {
  description = "POSIX group ID for access point"
  type        = number
  default     = 1000
}

variable "root_directory_path" {
  description = "Root directory path for access point"
  type        = string
  default     = "/"
}

variable "root_directory_permissions" {
  description = "Permissions for root directory"
  type        = string
  default     = "755"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
