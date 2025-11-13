# =============================================================================
# PeerPrep EC2 Deployment - Terraform Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "peerprep"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "ec2-prod"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large" # 2 vCPU, 8GB RAM
  # Alternative: t3.medium (4GB) for testing, t3.xlarge (16GB) for heavy load
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH (leave empty to disable SSH access)"
  type        = list(string)
  default     = [] # Add your IP: ["1.2.3.4/32"]
}

variable "github_repo_url" {
  description = "GitHub repository URL to clone"
  type        = string
  default     = "https://github.com/CS3219-AY2526Sem1/cs3219-ay2526s1-project-g19.git"
}

variable "github_branch" {
  description = "GitHub branch to checkout"
  type        = string
  default     = "prod/ec2-prod"
}

variable "key_name" {
  description = "EC2 key pair name (optional, for SSH access)"
  type        = string
  default     = ""
}

# =============================================================================
# Database Configuration (localhost for single EC2 instance)
# =============================================================================

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
  default     = "changeme_secure_password_min_20"
}

variable "secret_key" {
  description = "Django SECRET_KEY for production"
  type        = string
  sensitive   = true
  default     = "changeme_django_secret_key_min_50_chars_random"
}

# =============================================================================
# Secrets Management (Optional)
# =============================================================================

variable "use_secrets_manager" {
  description = "Pull secrets from AWS Secrets Manager instead of Terraform variables"
  type        = bool
  default     = false
}

variable "secrets_manager_name" {
  description = "Secrets Manager secret name (if use_secrets_manager=true). Example: peerprep/ec2-prod/env"
  type        = string
  default     = "peerprep/ec2-prod/env"
}

# =============================================================================
# Networking
# =============================================================================

variable "vpc_id" {
  description = "VPC ID to use (leave empty to use default VPC)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID to launch instance in (leave empty for default)"
  type        = string
  default     = ""
}

variable "elastic_ip_allocation_id" {
  description = "Pre-allocated Elastic IP allocation ID (permanent IP). If not specified, a new EIP will be created."
  type        = string
  default     = ""
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
