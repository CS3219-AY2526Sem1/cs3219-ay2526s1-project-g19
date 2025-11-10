variable "name_prefix" {
  description = "Prefix used for naming Redis resources"
  type        = string
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "vpc_id" {
  description = "VPC ID (reserved for future use)"
  type        = string
  default     = null
}

variable "cache_subnet_ids" {
  description = "Cache subnet IDs (reserved for future use)"
  type        = list(string)
  default     = []
}

variable "node_type" {
  description = "Instance class for Redis nodes"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (1 disables multi-AZ)"
  type        = number
  default     = 1
}

variable "cache_subnet_group_name" {
  description = "Existing ElastiCache subnet group for the cluster"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups attached to the Redis cluster"
  type        = list(string)
}

variable "maintenance_window" {
  description = "Weekly maintenance window"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "snapshot_window" {
  description = "Daily snapshot window"
  type        = string
  default     = "03:00-04:00"
}

variable "snapshot_retention_limit" {
  description = "Number of daily snapshots to retain"
  type        = number
  default     = 3
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for ElastiCache notifications"
  type        = string
  default     = null
}

variable "alarm_actions" {
  description = "List of alarm action ARNs for 