# =============================================================================
# PeerPrep EC2 Deployment - Main Infrastructure
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =============================================================================
# Data Sources
# =============================================================================

# Get default VPC if not specified
data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id == "" ? true : false
}

# Get default subnet if not specified
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# Get latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Look up existing Elastic IP if allocation ID is provided
data "aws_eip" "existing" {
  count = var.elastic_ip_allocation_id != "" ? 1 : 0
  id    = var.elastic_ip_allocation_id
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "peerprep" {
  name_prefix = "${var.project_name}-${var.environment}-sg-"
  description = "Security group for PeerPrep EC2 instance"
  vpc_id      = data.aws_vpc.selected.id

  # HTTP access from anywhere
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access (optional, only if allowed_ssh_cidr is specified)
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidr) > 0 ? [1] : []
    content {
      description = "SSH from allowed IPs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidr
    }
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-sg"
      Project     = var.project_name
      Environment = var.environment
    },
    var.tags
  )
}

# =============================================================================
# IAM Role for EC2 Instance (Session Manager + Secrets access)
# =============================================================================

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-ec2-role"
      Project     = var.project_name
      Environment = var.environment
    },
    var.tags
  )
}

# Attach SSM managed policy for Session Manager access (no SSH needed!)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom policy for Secrets Manager access
resource "aws_iam_role_policy" "secrets_manager" {
  count = var.use_secrets_manager ? 1 : 0
  name  = "${var.project_name}-${var.environment}-secrets-manager"
  role  = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_manager_name}*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-ec2-profile"
      Project     = var.project_name
      Environment = var.environment
    },
    var.tags
  )
}

# =============================================================================
# EC2 Instance
# =============================================================================

resource "aws_instance" "peerprep" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.peerprep.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      {
        Name        = "${var.project_name}-${var.environment}-root-volume"
        Project     = var.project_name
        Environment = var.environment
      },
      var.tags
    )
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    github_repo_url     = var.github_repo_url
    github_branch       = var.github_branch
    use_secrets_manager = var.use_secrets_manager
    secrets_manager_name = var.secrets_manager_name
    aws_region          = var.aws_region
  }))

  # Prevent replacement when user_data changes (use lifecycle)
  user_data_replace_on_change = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-instance"
      Project     = var.project_name
      Environment = var.environment
    },
    var.tags
  )
}

# =============================================================================
# Elastic IP
# =============================================================================

# =============================================================================
# Elastic IP (Conditional: Use pre-allocated or create new)
# =============================================================================

# Create new EIP only if elastic_ip_allocation_id is not provided
resource "aws_eip" "peerprep" {
  count    = var.elastic_ip_allocation_id == "" ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.peerprep.id

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-eip"
      Project     = var.project_name
      Environment = var.environment
    },
    var.tags
  )
}

# Associate pre-allocated EIP if allocation ID is provided
resource "aws_eip_association" "peerprep_existing" {
  count         = var.elastic_ip_allocation_id != "" ? 1 : 0
  instance_id   = aws_instance.peerprep.id
  allocation_id = var.elastic_ip_allocation_id
}
