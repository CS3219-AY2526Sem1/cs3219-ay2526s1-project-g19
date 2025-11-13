# PeerPrep AWS ECS Infrastructure - Terraform Configuration

This directory contains the Terraform configuration for deploying the PeerPrep microservices application on AWS ECS with Fargate.

## Architecture Overview

**Services (7 total):**
- Frontend (React + Nginx)
- User Service (FastAPI + PostgreSQL)
- Question Service (FastAPI + PostgreSQL)
- Matching Service (FastAPI + PostgreSQL + Redis)
- History Service (FastAPI + PostgreSQL)
- Collaboration Service (FastAPI + Redis with WebSocket)
- Chat Service (FastAPI + Redis with WebSocket)

**Infrastructure Components:**
- VPC with public and private subnets across 2 availability zones
- Application Load Balancer for path-based routing
- ECS Fargate for container orchestration
- 4 separate RDS PostgreSQL databases
- 3 separate ElastiCache Redis clusters
- AWS Cloud Map for service discovery
- Auto-scaling policies

## Project Structure

```
terraform/
├── main.tf                      # Root configuration
├── variables.tf                 # Global variables
├── outputs.tf                   # Infrastructure outputs
├── terraform.tfvars             # Your configuration values (gitignored)
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
└── modules/
    ├── vpc/                     # VPC, subnets, NAT, IGW
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security-groups/         # All security groups
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── rds/                     # RDS PostgreSQL (Phase 2)
    ├── elasticache/             # ElastiCache Redis (Phase 2)
    ├── alb/                     # Application Load Balancer (Phase 3)
    ├── ecs-cluster/             # ECS cluster + IAM roles (Phase 4)
    ├── ecs-service/             # Reusable service module (Phase 5)
    ├── service-discovery/       # AWS Cloud Map (Phase 5)
    └── autoscaling/             # Auto-scaling policies (Phase 6)
```

## Prerequisites

1. **AWS CLI configured** with credentials:
   ```bash
   aws configure
   ```

2. **Terraform installed** (version >= 1.5.0):
   ```bash
   terraform version
   ```

3. **Sufficient AWS permissions**:
   - VPC, EC2, ECS, RDS, ElastiCache
   - IAM roles and policies
   - CloudWatch logs

## Phase 1: VPC and Networking (Current Phase)

### What Gets Created

This phase creates the networking foundation:
- 1 VPC (`10.0.0.0/16`)
- 2 Public subnets (for ALB)
- 2 Private subnets (for ECS, RDS, Redis)
- 1 Internet Gateway
- 1 NAT Gateway (single NAT for cost savings)
- Route tables and associations
- Security groups:
  - ALB security group
  - ECS tasks security group
  - 4 RDS security groups (user, question, matching, history)
  - 3 Redis security groups (matching, collaboration, chat)

### Expected Resources

Running `terraform plan` should show approximately **30-35 resources** to be created:
- 1 VPC
- 2 public subnets
- 2 private subnets
- 1 Internet Gateway
- 1 NAT Gateway
- 1 Elastic IP
- 3 route tables
- 4 route table associations
- 1 ALB security group (+ 3 rules)
- 1 ECS security group (+ 4 rules)
- 4 DB security groups (+ 8 rules)
- 3 Redis security groups (+ 6 rules)

## Verification Steps for Phase 1

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
```

**Expected output:**
```
Initializing modules...
- security_groups in modules/security-groups
- vpc in modules/vpc

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Step 2: Validate Configuration

```bash
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### Step 3: Format Code (Optional)

```bash
terraform fmt -recursive
```

### Step 4: Review the Plan

```bash
terraform plan
```

**What to check:**
1. Number of resources: Should be ~30-35 resources to add
2. VPC CIDR: `10.0.0.0/16`
3. Subnets: 2 public (`10.0.1.0/24`, `10.0.2.0/24`), 2 private (`10.0.11.0/24`, `10.0.12.0/24`)
4. NAT Gateway: 1 NAT Gateway in first public subnet
5. Security Groups: 9 total (1 ALB, 1 ECS, 4 DB, 3 Redis)

**Sample plan output:**
```
Plan: 35 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_security_group_id = (known after apply)
  + ecs_security_group_id = (known after apply)
  + internet_gateway_id   = (known after apply)
  + nat_gateway_ids       = [
      + (known after apply),
    ]
  + private_subnet_ids    = [
      + (known after apply),
      + (known after apply),
    ]
  + public_subnet_ids     = [
      + (known after apply),
      + (known after apply),
    ]
  + vpc_id                = (known after apply)
```

### Step 5: Save the Plan (Optional)

```bash
terraform plan -out=phase1.tfplan
```

## Configuration

### Key Variables (terraform.tfvars)

```hcl
# Global settings
aws_region   = "ap-southeast-1"
project_name = "peerprep"
environment  = "prod"

# VPC and networking
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Cost optimization
single_nat_gateway = true  # Use single NAT Gateway for all AZs
```

### Customization

To modify the configuration:

1. **Change region**: Update `aws_region` in `terraform.tfvars`
2. **Change VPC CIDR**: Update `vpc_cidr` in `terraform.tfvars`
3. **Add more AZs**: Add more subnet CIDRs to `public_subnet_cidrs` and `private_subnet_cidrs`
4. **High availability NAT**: Set `single_nat_gateway = false` (increases cost by ~$35/month per NAT)

## Troubleshooting

### Error: "No valid credential sources found"

```bash
aws configure
# Enter your AWS Access Key ID and Secret Access Key
```

### Error: "Error: creating EC2 VPC: VpcLimitExceeded"

You've reached the VPC limit for your region. Delete unused VPCs or request a limit increase.

### Error: "Error: creating EC2 EIP: AddressLimitExceeded"

You've reached the Elastic IP limit. Release unused EIPs or request a limit increase.

### Validation Error: "Invalid for_each argument"

This usually means Terraform needs to be initialized again:
```bash
terraform init -upgrade
```

## Cost Estimate for Phase 1

**Monthly costs:**
- NAT Gateway: $32.85 (1 NAT × $0.045/hour × 730 hours)
- NAT Gateway data transfer: ~$2-5 (depends on usage)
- **Total Phase 1**: ~$35-40/month

**Note:** Additional costs will be added in subsequent phases (RDS, Redis, ECS, ALB).

## Cleaning Up

To destroy all resources created by Terraform:

```bash
terraform destroy
```

**WARNING:** This will delete ALL infrastructure. Make sure you have backups!

## Next Steps

Once Phase 1 is verified:

1. **Review the plan output** carefully
2. **Report back** with the number of resources and any errors
3. **Proceed to Phase 2**: RDS + ElastiCache (when ready)

### Phase 2 Preview

Phase 2 will add:
- 4 RDS PostgreSQL instances (db.t3.micro, Multi-AZ)
- 3 ElastiCache Redis clusters (cache.t3.micro, 2 nodes each)
- Approximately 20-25 additional resources

## Support

For issues or questions:
1. Check AWS CloudFormation events for detailed error messages
2. Review Terraform state: `terraform show`
3. Enable detailed logging: `export TF_LOG=DEBUG`

## Security Notes

- `terraform.tfvars` contains sensitive configuration and is gitignored
- Never commit AWS credentials to version control
- Use AWS Secrets Manager for database passwords in production
- Review security group rules before deploying to production
- Consider enabling VPC Flow Logs for network monitoring

## References

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
