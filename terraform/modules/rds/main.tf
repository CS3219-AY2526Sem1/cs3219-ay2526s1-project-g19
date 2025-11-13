# =============================================================================
# RDS PostgreSQL Module
# =============================================================================
# Creates a single RDS PostgreSQL instance with 4 databases:
# - question_db
# - matching_db
# - history_db
# - user_db
#
# Features:
# - Multi-AZ deployment for high availability
# - Automatic backups
# - Automated storage scaling
# - Enhanced monitoring
# - Encryption at rest
# =============================================================================

# -----------------------------------------------------------------------------
# RDS Instance
# -----------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-postgres"

  # Engine configuration
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.db_instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database credentials
  db_name  = var.database_names[0] # Create the first database automatically
  username = var.master_username
  password = var.master_password

  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false

  # High availability
  multi_az = var.multi_az

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Deletion protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Apply changes immediately (use with caution in production)
  apply_immediately = var.apply_immediately

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-postgres"
    }
  )
}

# -----------------------------------------------------------------------------
# Parameter Group (PostgreSQL tuning)
# -----------------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.name_prefix}-postgres-"
  family      = "postgres15"
  description = "Custom parameter group for ${var.name_prefix}"

  # Connection pooling settings (static - requires reboot)
  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }

  # Memory settings (static - requires reboot)
  parameter {
    name         = "shared_buffers"
    value        = "{DBInstanceClassMemory/32768}" # 25% of memory
    apply_method = "pending-reboot"
  }

  # WAL settings for performance (static - requires reboot)
  parameter {
    name         = "wal_buffers"
    value        = "2048"
    apply_method = "pending-reboot"
  }

  # Query tuning
  parameter {
    name  = "random_page_cost"
    value = "1.1" # SSD optimized
  }

  # Logging
  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries > 1 second
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-postgres-params"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring
# -----------------------------------------------------------------------------

resource "aws_iam_role" "rds_monitoring" {
  name_prefix = "${var.name_prefix}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-monitoring-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# -----------------------------------------------------------------------------
# Create Additional Databases
# -----------------------------------------------------------------------------
# Note: RDS creates the first database automatically (db_name parameter)
# Additional databases need to be created via SQL after the instance is ready
# This is typically done via database migration scripts

# We'll create a null_resource to run SQL commands after RDS is ready
# This requires the psql client and network access to RDS

resource "null_resource" "create_databases" {
  count = length(var.database_names) > 1 ? 1 : 0

  # Trigger recreation when database list changes
  triggers = {
    database_names = join(",", var.database_names)
    db_endpoint    = aws_db_instance.main.endpoint
  }

  # This assumes you have psql installed and can reach the RDS instance
  # In production, you might want to use a Lambda function or ECS task instead
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for RDS to be fully available
      sleep 60

      # Create additional databases (skip the first one, it's already created)
      ${join("\n", [
    for db in slice(var.database_names, 1, length(var.database_names)) :
    "PGPASSWORD='${var.master_password}' psql -h ${aws_db_instance.main.address} -U ${var.master_username} -d ${var.database_names[0]} -c 'CREATE DATABASE ${db};' || true"
])}
    EOT

interpreter = ["/bin/bash", "-c"]
}

depends_on = [aws_db_instance.main]
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.name_prefix}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_memory" {
  alarm_name          = "${var.name_prefix}-rds-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 256000000 # 256 MB
  alarm_description   = "RDS freeable memory is too low"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_storage" {
  alarm_name          = "${var.name_prefix}-rds-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2000000000 # 2 GB
  alarm_description   = "RDS free storage space is too low"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.tags
}
