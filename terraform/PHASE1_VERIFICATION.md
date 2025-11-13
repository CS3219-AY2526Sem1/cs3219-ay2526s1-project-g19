# Phase 1 Verification Guide

## Quick Start - Verification Commands

Run these commands in order to verify Phase 1 is working correctly:

### 1. Navigate to terraform directory

```bash
cd "/Users/kimshitong/Library/CloudStorage/OneDrive-NationalUniversityofSingapore/8. NUS Work/cs3219-ay2526s1-project-g19/terraform"
```

### 2. Initialize Terraform

```bash
terraform init
```

**What to expect:**
- Downloads AWS provider plugins
- Initializes modules (vpc, security-groups)
- Creates `.terraform` directory
- Creates `.terraform.lock.hcl` file

**Success output:**
```
✓ Terraform has been successfully initialized!
```

**If it fails:**
- Check AWS CLI is configured: `aws sts get-caller-identity`
- Check Terraform is installed: `terraform version`

### 3. Validate Configuration

```bash
terraform validate
```

**What to expect:**
- Checks syntax of all `.tf` files
- Validates module references
- Checks variable types

**Success output:**
```
Success! The configuration is valid.
```

**If it fails:**
- Read the error message carefully
- Common issues: typos in resource names, invalid variable types
- Run `terraform fmt` to auto-format files

### 4. Format Code (optional but recommended)

```bash
terraform fmt -recursive
```

This will auto-format all Terraform files to follow best practices.

### 5. Generate and Review Plan

```bash
terraform plan
```

**What to expect:**
This command shows what will be created WITHOUT actually creating anything.

**Expected output summary:**
```
Plan: 35 to add, 0 to change, 0 to destroy.
```

**Resources to be created (~35 total):**

**VPC Resources (10):**
- 1 × aws_vpc.main
- 2 × aws_subnet.public
- 2 × aws_subnet.private
- 1 × aws_internet_gateway.main
- 1 × aws_eip.nat
- 1 × aws_nat_gateway.main
- 1 × aws_route_table.public
- 2 × aws_route_table.private

**Routing (7):**
- 1 × aws_route.public_internet
- 2 × aws_route.private_nat
- 2 × aws_route_table_association.public
- 2 × aws_route_table_association.private

**Security Groups (18):**
- 1 × aws_security_group.alb
- 3 × aws_vpc_security_group_ingress_rule (alb)
- 1 × aws_vpc_security_group_egress_rule (alb)
- 1 × aws_security_group.ecs
- 3 × aws_vpc_security_group_ingress_rule (ecs)
- 1 × aws_vpc_security_group_egress_rule (ecs)
- 4 × aws_security_group.db (user, question, matching, history)
- 4 × aws_vpc_security_group_ingress_rule (db)
- 4 × aws_vpc_security_group_egress_rule (db)
- 3 × aws_security_group.redis (matching, collaboration, chat)
- 3 × aws_vpc_security_group_ingress_rule (redis)
- 3 × aws_vpc_security_group_egress_rule (redis)

### 6. Check Specific Resources

After running `terraform plan`, look for these specific resources:

#### VPC Configuration
```
+ resource "aws_vpc" "main" {
    + cidr_block           = "10.0.0.0/16"
    + enable_dns_hostnames = true
    + enable_dns_support   = true
}
```

#### Public Subnets
```
+ resource "aws_subnet" "public" {
    + cidr_block              = "10.0.1.0/24"  # and 10.0.2.0/24
    + map_public_ip_on_launch = true
}
```

#### NAT Gateway
```
+ resource "aws_nat_gateway" "main" {
    # Should be in first public subnet
}
```

#### Security Groups
```
+ resource "aws_security_group" "alb"
+ resource "aws_security_group" "ecs"
+ resource "aws_security_group" "db["user"]
+ resource "aws_security_group" "db["question"]
+ resource "aws_security_group" "db["matching"]
+ resource "aws_security_group" "db["history"]
+ resource "aws_security_group" "redis["matching"]
+ resource "aws_security_group" "redis["collaboration"]
+ resource "aws_security_group" "redis["chat"]
```

### 7. Save the Plan (optional)

```bash
terraform plan -out=phase1.tfplan
```

This saves the plan to a file so you can apply it later without re-calculating.

### 8. View Planned Outputs

After running `terraform plan`, scroll to the bottom to see outputs:

```
Changes to Outputs:
  + vpc_id                  = (known after apply)
  + public_subnet_ids       = [
      + (known after apply),
      + (known after apply),
    ]
  + private_subnet_ids      = [
      + (known after apply),
      + (known after apply),
    ]
  + alb_security_group_id   = (known after apply)
  + ecs_security_group_id   = (known after apply)
  + db_security_group_ids   = {
      + history  = (known after apply)
      + matching = (known after apply)
      + question = (known after apply)
      + user     = (known after apply)
    }
  + redis_security_group_ids = {
      + chat          = (known after apply)
      + collaboration = (known after apply)
      + matching      = (known after apply)
    }
```

## Checklist for Phase 1 Verification

Mark these as complete:

- [ ] `terraform init` runs successfully
- [ ] `terraform validate` shows "Success!"
- [ ] `terraform plan` shows ~35 resources to add
- [ ] VPC CIDR is `10.0.0.0/16`
- [ ] 2 public subnets created
- [ ] 2 private subnets created
- [ ] 1 NAT Gateway created
- [ ] 1 ALB security group created
- [ ] 1 ECS security group created
- [ ] 4 DB security groups created
- [ ] 3 Redis security groups created
- [ ] No errors or warnings in plan output

## What to Report Back

After running the verification commands, report:

1. **terraform init result**: Success or error message
2. **terraform validate result**: Success or error message
3. **terraform plan summary**: Number of resources to add
4. **Any warnings or errors**: Copy the full error message
5. **Ready for Phase 2?**: Yes or No

## Example Success Report

```
✅ Phase 1 Verification Complete

terraform init: Success
terraform validate: Success
terraform plan: 35 resources to add, 0 to change, 0 to destroy

VPC Configuration:
- VPC CIDR: 10.0.0.0/16
- Public subnets: 10.0.1.0/24, 10.0.2.0/24
- Private subnets: 10.0.11.0/24, 10.0.12.0/24
- NAT Gateways: 1 (cost savings mode)

Security Groups:
- 1 ALB security group
- 1 ECS security group
- 4 DB security groups (user, question, matching, history)
- 3 Redis security groups (matching, collaboration, chat)

No errors or warnings found.
Ready for Phase 2: YES
```

## Common Issues and Solutions

### Issue: "Error: No valid credential sources found"

**Solution:**
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter region: ap-southeast-1
```

### Issue: "Error: Module not installed"

**Solution:**
```bash
terraform init -upgrade
```

### Issue: "Error: Invalid for_each argument"

This usually happens if Terraform hasn't been initialized properly.

**Solution:**
```bash
rm -rf .terraform
rm .terraform.lock.hcl
terraform init
```

### Issue: "Error: Unsupported argument"

Check for typos in resource names or arguments.

**Solution:**
```bash
terraform fmt -recursive
terraform validate
```

### Issue: "Warning: Quoted type constraints are deprecated"

This is just a warning, not an error. The plan will still work.

## Do NOT Apply Yet!

**IMPORTANT:** Do NOT run `terraform apply` yet!

We want to verify the plan first and make sure everything looks correct before actually creating resources on AWS.

Once you've verified Phase 1 is working correctly, we'll move to Phase 2 (RDS + ElastiCache).

## Next Steps

After successful verification:

1. Review the plan output carefully
2. Report back with results
3. Ask any questions about the resources being created
4. Proceed to Phase 2 when ready

## Cost Reminder

**Phase 1 costs (if applied):**
- NAT Gateway: ~$35/month
- Data transfer: ~$2-5/month
- **Total: ~$40/month**

No charges until you run `terraform apply`.
