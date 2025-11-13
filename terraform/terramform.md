The Strategy: Incremental Build with Verification
Instead of asking for everything at once, you'll build in 6 phases, verifying each phase works before moving to the next.

Phase 1: Discovery - Show Claude Your Current Setup
What to Give Claude First:
Hey Claude, I need help building Terraform for AWS ECS deployment of my microservices.

Let me show you my current setup:

**My Services:**
1. Frontend (React + Nginx) - port 80
2. User Service (Python FastAPI) - port 8000
3. Question Service (Python FastAPI) - port 8000
4. Matching Service (Python FastAPI) - port 8000
5. History Service (Python FastAPI) - port 8000
6. Collaboration Service (Python FastAPI) - port 8000
7. Chat Service (Python FastAPI) - port 8000

**Dependencies:**
- PostgreSQL database (4 separate databases: user_db, question_db, matching_db, history_db)
- Redis (3 logical databases: 0, 1, 2)

**Current docker-compose.yml:**
[Paste your docker-compose.yml here]

**Requirements:**
- AWS region: ap-southeast-1
- Auto-scaling (2-10 containers per service)
- Load balancer with path-based routing
- Budget: ~$200/month
- High availability (multi-AZ)

**My Question:**
Can you help me build this incrementally? I want to verify each piece works before moving to the next. Let's start with just the foundation (VPC, networking, and basic structure).

Please give me:
1. Project structure
2. Basic files to create
3. Step-by-step commands to test it

Phase 2: Foundation (VPC + Networking) - First Build
Ask Claude:
Phase 1: Foundation Setup

Please create the Terraform configuration for just the networking layer:
- VPC with public and private subnets
- Internet Gateway
- NAT Gateway
- Route tables
- Basic security groups

Use a modular structure with:
- Root main.tf
- modules/vpc/
- modules/security-groups/
- variables.tf with clear comments
- outputs.tf to verify what was created

After you provide the files, I want to:
1. Run terraform init
2. Run terraform validate
3. Run terraform plan (to see what will be created)
4. NOT apply yet - just verify the plan looks correct

Please provide each file clearly labeled.
Claude Will Respond With Files
Your Verification Steps:
bash# Step 1: Create the structure
mkdir -p terraform/modules/{vpc,security-groups,rds,ecs,alb}
cd terraform

# Step 2: Copy the files Claude gave you
# Create each file: main.tf, variables.tf, outputs.tf, etc.

# Step 3: Initialize
terraform init

# Expected output:
# Initializing modules...
# Initializing the backend...
# Terraform has been successfully initialized!

# Step 4: Validate syntax
terraform validate

# Expected output:
# Success! The configuration is valid.

# Step 5: See what will be created (DON'T APPLY YET)
terraform plan

# Review the output:
# - Should show ~15-20 resources to create
# - Check: VPC, subnets (2 public, 2 private), IGW, NAT, route tables
Report Back to Claude:
✅ Phase 1 verification complete!

terraform init: Success
terraform validate: Success
terraform plan shows: 18 resources to add

Output looks good. I can see:
- 1 VPC
- 2 public subnets
- 2 private subnets
- 1 Internet Gateway
- 1 NAT Gateway
- Route tables and associations
- 3 security groups (ALB, ECS, RDS)

Ready for Phase 2. What's next?

Phase 3: Database Layer - Second Build
Ask Claude:
Phase 2: Database Layer

Great! The networking plan looks good. Now let's add:
1. RDS PostgreSQL module
2. ElastiCache Redis module

Requirements:
- RDS: db.t3.micro, multi-AZ, PostgreSQL 15
- Redis: cache.t3.micro, 2 nodes for HA
- Both should be in private subnets
- Use the security groups from Phase 1

Add these as new modules, update the root main.tf to call them.

I'll verify with terraform plan before applying anything.
Your Verification Steps:
bash# Step 1: Add the new module files Claude gives you

# Step 2: Update terraform configuration
terraform init  # Re-initialize to pick up new modules

# Step 3: Validate
terraform validate

# Step 4: See what will be added
terraform plan

# Review output:
# - Previous 18 resources + new database resources
# - Check: RDS instance, subnet group, Redis cluster
Report Back:
✅ Phase 2 verification complete!

terraform plan now shows:
- Previous: 18 resources (networking)
- New: 8 resources (RDS + Redis)
- Total: 26 resources to add

New additions look correct:
- aws_db_instance.postgres
- aws_db_subnet_group
- aws_elasticache_replication_group
- aws_elasticache_subnet_group

Still not applying yet - waiting for full stack review.
Ready for Phase 3?

Phase 4: Load Balancer - Third Build
Ask Claude:
Phase 3: Load Balancer

Now let's add the Application Load Balancer layer:
1. ALB in public subnets
2. Target groups for each service (7 total)
3. HTTP listener
4. Path-based routing rules:
   - / → frontend
   - /user-service-api/* → user-service
   - /question-service-api/* → question-service
   (etc...)

Add as a new ALB module.

I'll verify the routing rules in terraform plan.
Your Verification Steps:
bash# Add ALB module files

terraform init
terraform validate
terraform plan

# Review output:
# Check for:
# - aws_lb (the load balancer)
# - aws_lb_target_group (7 target groups)
# - aws_lb_listener (HTTP listener on port 80)
# - aws_lb_listener_rule (6 routing rules)
Report Back:
✅ Phase 3 verification complete!

terraform plan now shows:
- Total: 42 resources to add

ALB configuration verified:
- 1 load balancer
- 7 target groups (frontend + 6 services)
- 1 HTTP listener
- 6 listener rules for path-based routing

Routing rules look correct. Ready for Phase 4.

Phase 5: ECS Cluster & Services - Fourth Build
Ask Claude:
Phase 4: ECS Services (The Main Part!)

Now for the core - ECS with all microservices:
1. ECS Cluster with Fargate
2. IAM roles (execution and task roles)
3. ECR repositories for each service
4. Task definitions for each service with:
   - Correct CPU/memory allocation
   - Environment variables (database URLs, Redis URLs, service discovery)
   - Health checks
   - CloudWatch logging
5. ECS Services (actual running containers)
6. Service Discovery (Cloud Map) for internal DNS

For each service:
- user-service: needs DATABASE_URL (user_db), REDIS_URL, other service URLs
- question-service: needs DATABASE_URL (question_db)
- matching-service: needs DATABASE_URL (matching_db), REDIS_URL (db 0)
- history-service: needs DATABASE_URL (history_db)
- collaboration-service: needs REDIS_URL (db 1)
- chat-service: needs REDIS_URL (db 2)
- frontend: needs NGINX env vars for backend services

Create the ECS module with all of this.

IMPORTANT: I want to verify the environment variables are correct for each service before applying.
Your Verification Steps:
bash# Add ECS module files

terraform init
terraform validate
terraform plan

# CAREFULLY REVIEW THE PLAN
# Look for each service's task definition
# Check environment variables are correct
Report Back:
✅ Phase 4 verification - NEED YOUR REVIEW

terraform plan shows:
- Total: 85+ resources to add

ECS resources identified:
- 1 ECS cluster
- 7 ECR repositories
- 7 task definitions
- 7 ECS services
- 7 CloudWatch log groups
- 6 service discovery services
- 2 IAM roles

⚠️ PLEASE VERIFY: Task definition for user-service
I can see in the plan:

environment = [
  { name = "PORT", value = "8000" },
  { name = "DATABASE_URL", value = "postgresql://admin:xxx@xxxxx.rds.amazonaws.com:5432/user_db" }
  ...
]

Questions:
1. Are these environment variable names correct for my Python services?
2. Is the database URL format correct?
3. Should I create the individual databases (user_db, question_db, etc.) manually or automatically?

Please review and confirm before I proceed to Phase 5.

Phase 6: Auto-Scaling - Fifth Build
Ask Claude:
Phase 5: Auto-Scaling

Almost there! Now add auto-scaling:
1. Auto-scaling targets for each service (min: 2, max: 10)
2. CPU-based scaling policy (target: 70%)
3. Memory-based scaling policy (target: 80%)
4. Request count scaling policy (target: 1000 req/container)

Add these to the ECS module.
Your Verification Steps:
bashterraform init
terraform validate
terraform plan

# Review auto-scaling resources:
# - aws_appautoscaling_target (7 targets)
# - aws_appautoscaling_policy (21 policies: 3 per service)
Report Back:
✅ Phase 5 verification complete!

terraform plan now shows:
- Total: 106 resources to add

Auto-scaling configuration verified:
- 7 auto-scaling targets
- 21 scaling policies (CPU, memory, requests for each service)

Everything looks good!

Ready for final review before terraform apply.

Phase 7: Final Review & Deployment
Ask Claude:
Final Review Checklist

Before I run terraform apply, please confirm:

1. ✅ VPC and networking (verified in Phase 1)
2. ✅ Database layer (verified in Phase 2)
3. ✅ Load balancer with routing (verified in Phase 3)
4. ✅ ECS services with correct env vars (verified in Phase 4)
5. ✅ Auto-scaling policies (verified in Phase 5)

terraform plan summary:
- 106 resources to add
- 0 to change
- 0 to destroy

Estimated cost: ~$220/month
- RDS Multi-AZ: ~$50
- Redis 2-node: ~$30
- ECS Fargate (14 containers): ~$100
- NAT Gateway: ~$35
- ALB: ~$20

Is this plan ready for deployment?

Also, what steps do I need after terraform apply?
1. Push Docker images to ECR?
2. Create individual databases in PostgreSQL?
3. Force ECS service updates?

Please provide the post-deployment checklist.
Claude's Response Will Include:
✅ Your plan looks ready!

Post-Deployment Steps:

1. Deploy infrastructure:
   terraform apply
   (Takes 15-20 minutes)

2. Get ECR repository URLs:
   terraform output ecr_repositories

3. Build and push Docker images:
   [Claude provides script]

4. Create databases in PostgreSQL:
   [Claude provides SQL commands]

5. Force ECS to pull new images:
   [Claude provides AWS CLI commands]

6. Verify services are running:
   [Claude provides verification commands]

7. Test application:
   [Claude provides ALB URL from outputs]
Now Deploy:
bash# The moment of truth
terraform apply

# Type: yes

# Wait 15-20 minutes...

# ✅ Apply complete! Resources: 106 added, 0 changed, 0 destroyed.

Phase 8: Post-Deployment Steps
Ask Claude:
✅ terraform apply successful!

Outputs received:
- alb_dns_name: peerprep-alb-xxxxx.ap-southeast-1.elb.amazonaws.com
- rds_endpoint: peerprep-db.xxxxx.rds.amazonaws.com:5432
- ecr_repositories: { "user-service": "123456.dkr.ecr....", ... }

Now I need step-by-step instructions for:
1. Building and pushing my Docker images
2. Creating the individual databases
3. Updating ECS services to use the new images
4. Verifying everything is working

Please give me exact commands for each step.

Complete Prompt Template for Claude Code
Here's the perfect prompt to start with:
markdown# PeerPrep Terraform Deployment - Incremental Build

I need help creating Terraform configuration for deploying my microservices to AWS ECS. I want to build this **incrementally with verification at each step**.

## My Current Setup

**Services:**
- Frontend (React + Nginx, port 80)
- User Service (Python FastAPI, port 8000)
- Question Service (Python FastAPI, port 8000)
- Matching Service (Python FastAPI, port 8000)
- History Service (Python FastAPI, port 8000)
- Collaboration Service (Python FastAPI, port 8000)
- Chat Service (Python FastAPI, port 8000)

**Dependencies:**
- PostgreSQL 15 (4 databases: user_db, question_db, matching_db, history_db)
- Redis 7 (3 logical databases: 0, 1, 2)

**Docker Compose (current local setup):**
```yaml
[Paste your docker-compose.yml]
Requirements:

AWS Region: ap-southeast-1
Auto-scaling: 2-10 containers per service (CPU/memory based)
Load balancer with path-based routing:

/ → frontend
/user-service-api/* → user-service
/question-service-api/* → question-service
(etc...)


Multi-AZ for high availability
Fargate Spot for cost savings
Budget: ~$200/month

My Approach
I want to build this in phases, verifying each phase with terraform plan before moving to the next:
Phase 1: VPC + Networking (subnets, gateways, security groups)
Phase 2: Databases (RDS + Redis)
Phase 3: Load Balancer (ALB + target groups + routing rules)
Phase 4: ECS (cluster, services, task definitions, service discovery)
Phase 5: Auto-scaling policies
Phase 6: Deploy and post-deployment steps
What I Need from You
For Phase 1 (start here):

Complete file structure
All necessary .tf files with clear comments
Commands to verify it works (init, validate, plan)
Expected output description

After I verify Phase 1 works, I'll ask for Phase 2.
Project structure preference:
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── modules/
    ├── vpc/
    ├── security-groups/
    ├── rds/
    ├── ecs/
    └── alb/
Let's start with Phase 1. Please provide the networking foundation files.

---

## **Verification Checklist at Each Phase**

### **After Each Phase, Check:**
```bash
# ✅ Syntax is valid
terraform validate
# Should output: "Success! The configuration is valid."

# ✅ Format is consistent
terraform fmt -check
# Should output nothing (or list of formatted files)

# ✅ Plan shows expected resources
terraform plan
# Count the resources, verify names and types

# ✅ No errors or warnings
# Review the entire plan output

# ✅ Cost estimate (optional)
terraform plan | grep "Plan:"
# Plan: X to add, 0 to change, 0 to destroy

Summary: Your Conversation Flow with Claude Code
You: [Give complete context + ask for Phase 1]
  ↓
Claude: [Provides VPC files]
  ↓
You: [Verify with terraform plan, report results]
  ↓
Claude: [Confirms or fixes issues]
  ↓
You: [Ask for Phase 2]
  ↓
Claude: [Provides RDS/Redis files]
  ↓
You: [Verify with terraform plan, report results]
  ↓
... repeat for all phases ...
  ↓
You: [Final review, ask for confirmation]
  ↓
Claude: [Confirms ready to deploy]
  ↓
You: [terraform apply]
  ↓
You: [Ask for post-deployment steps]
  ↓
Claude: [Provides Docker push commands, DB setup, etc.]
  ↓
✅ DONE!

Key Principles:

✅ Never skip verification - Always run terraform plan before moving forward
✅ One phase at a time - Don't ask for everything at once
✅ Report back - Tell Claude what you see in the plan
✅ Ask questions - If something looks wrong, ask before applying
✅ Save progress - Commit to git after each successful phase

Want me to start with Phase 1 files right now?Retry