# PeerPrep EC2 Single-Instance Deployment

This directory contains Terraform infrastructure code to deploy the entire PeerPrep microservices application on a **single EC2 instance** with Docker Compose.

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         Internet (Public Access)                 │
└─────────────────┬───────────────────────────────┘
                  │
         ┌────────▼────────┐
         │  Elastic IP     │ http://54.x.x.x
         └────────┬────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│       EC2 Instance (Ubuntu 24.04)                │
│           t3.large (2 vCPU, 8GB RAM)             │
│  ┌──────────────────────────────────────────┐   │
│  │  Docker Compose Stack                    │   │
│  │                                          │   │
│  │  Shared Infrastructure:                  │   │
│  │  ┌────────────┐  ┌──────────────────┐   │   │
│  │  │ PostgreSQL │  │  Redis           │   │   │
│  │  │ - question │  │  - DB 0: Match   │   │   │
│  │  │ - user     │  │  - DB 1: Collab  │   │   │
│  │  │ - history  │  │  - DB 2: Chat    │   │   │
│  │  │ - matching │  └──────────────────┘   │   │
│  │  └────────────┘                          │   │
│  │                                          │   │
│  │  Microservices:                          │   │
│  │  - Frontend (Nginx :80)                  │   │
│  │  - Question Service                      │   │
│  │  - User Service                          │   │
│  │  - History Service                       │   │
│  │  - Matching Service                      │   │
│  │  - Collaboration Service                 │   │
│  │  - Chat Service                          │   │
│  └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

### Key Design Decisions

**✅ Single PostgreSQL Container**
- Hosts 4 separate databases: `question_db`, `user_db`, `history_db`, `matching_db`
- Each service connects to its own database for isolation
- Simpler than managing 4 separate PostgreSQL containers
- Standard practice for small-to-medium deployments

**✅ Single Redis Container**
- Uses 3 different database indexes (Redis supports 0-15)
  - DB 0: Matching service (user queues, match state)
  - DB 1: Collaboration service (room state, documents)
  - DB 2: Chat service (messages, presence)
- Logical isolation without multiple containers
- Much simpler than managing 3 Redis instances

**✅ Automated Bootstrap**
- `user_data.sh` script handles entire setup
- Git clone → Docker install → Database init → Service startup
- Zero manual SSH required (uses cloud-init)

**✅ Cost-Effective**
- ~$68/month vs ~$150+ for managed AWS services (RDS + ElastiCache + ECS)
- Perfect for development, staging, or small production workloads
- Easy to scale up to managed services later

---

## Prerequisites

1. **AWS Account** with permissions to create:
   - EC2 instances
   - Security groups
   - Elastic IPs
   - IAM roles

2. **Local Tools**:
   - [Terraform](https://www.terraform.io/downloads) >= 1.0
   - [AWS CLI](https://aws.amazon.com/cli/) configured (`aws configure`)
   - SSH key pair (optional, for backup access)

3. **Repository Access**:
   - Public GitHub repo or
   - Private repo with deploy keys configured on EC2

---

## Quick Start (5 Minutes)

### 1. Configure Variables

Create `terraform.tfvars` in this directory:

```hcl
# terraform_ec2/terraform.tfvars

aws_region        = "us-east-1"
project_name      = "peerprep"
environment       = "ec2-prod"
instance_type     = "t3.large"      # or t3.medium for testing
github_repo_url   = "https://github.com/CS3219-AY2526Sem1/cs3219-ay2526s1-project-g19.git"
github_branch     = "prod/ec2-prod"

# Security: Restrict SSH to your IP (optional)
# Get your IP: curl ifconfig.me
allowed_ssh_cidr  = ["1.2.3.4/32"]  # Replace with your IP

# Optional: Use existing EC2 key pair for SSH
# key_name = "my-ec2-keypair"

# IMPORTANT: Change these secrets!
db_password = "your_secure_db_password_min_20_chars"
secret_key  = "your_django_secret_key_min_50_chars_random"
```

**Generate a secure Django secret key**:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
```

### 2. Initialize Terraform

```bash
cd terraform_ec2
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

This will show you:
- EC2 instance to be created
- Security group rules
- Elastic IP assignment
- IAM roles

### 4. Deploy

```bash
terraform apply
```

Type `yes` when prompted. Terraform will create all infrastructure in ~2 minutes.

### 5. Wait for Bootstrap (5-7 minutes)

The `user_data.sh` script runs automatically and:
1. Installs Docker & Docker Compose
2. Clones your repository
3. Creates environment file
4. Initializes databases
5. Builds and starts all services

**Monitor progress**:
```bash
# Get the Elastic IP from Terraform output
terraform output instance_public_ip

# SSH into the instance (if key_name configured)
ssh ubuntu@<ELASTIC_IP>

# Watch bootstrap logs
tail -f /var/log/cloud-init-output.log

# Check when Docker services are up
cd /opt/peerprep/terraform_ec2
docker compose -f docker-compose.ec2.yml ps
```

### 6. Access Your Application

```bash
# Get the application URL
terraform output application_url
# Example: http://54.123.45.67
```

Open the URL in your browser. You should see the PeerPrep frontend!

---

## File Structure

```
terraform_ec2/
├── main.tf                    # Core infrastructure (EC2, VPC, security groups)
├── variables.tf               # Input variables with defaults
├── outputs.tf                 # Outputs (Elastic IP, URLs, commands)
├── terraform.tfvars           # Your configuration (CREATE THIS - not in git)
├── user_data.sh.tpl          # Bootstrap script (auto-executed on first boot)
├── docker-compose.ec2.yml    # Docker Compose for single-instance deployment
├── .env.ec2.example          # Environment template (for reference)
└── README.md                  # This file
```

---

## Configuration Options

### Instance Sizing

| Instance Type | vCPU | RAM   | Best For                          | Cost/Month* |
|---------------|------|-------|-----------------------------------|-------------|
| t3.medium     | 2    | 4 GB  | Testing, light dev workloads      | ~$30        |
| t3.large      | 2    | 8 GB  | **Recommended** for full stack    | ~$60        |
| t3.xlarge     | 4    | 16 GB | Heavy load, many concurrent users | ~$120       |

*Pricing for us-east-1 region, on-demand. Use reserved instances for 40-60% savings.

### Storage

Default: 30GB gp3 SSD (~$3/month)
- Adjust `root_volume_size` in `terraform.tfvars` if needed
- Includes OS, Docker images, databases, logs

### Networking

**Security Group Rules** (auto-configured):
- Port 80 (HTTP): `0.0.0.0/0` (public web access)
- Port 443 (HTTPS): `0.0.0.0/0` (for future SSL)
- Port 22 (SSH): Only your IP (if `allowed_ssh_cidr` set)

**Elastic IP**: Static public IP that persists across instance restarts

---

## Advanced Configuration

### Option 1: Use AWS Secrets Manager (Recommended for Production)

Instead of passing secrets as Terraform variables, store them in AWS SSM Parameter Store:

**Step 1: Create SSM parameter**
```bash
aws ssm put-parameter \
  --name "/peerprep/ec2-prod/env" \
  --type "SecureString" \
  --value "$(cat .env.ec2)" \
  --region us-east-1
```

**Step 2: Enable in `terraform.tfvars`**
```hcl
use_ssm_secrets = true
ssm_secret_path = "/peerprep/ec2-prod/env"
```

The instance will fetch secrets at boot via IAM role.

### Option 2: Custom VPC/Subnet

By default, uses the default VPC. To use a custom VPC:

```hcl
vpc_id    = "vpc-12345678"
subnet_id = "subnet-87654321"
```

### Option 3: Multiple Environments

Deploy multiple isolated environments:

```bash
# Development
terraform workspace new dev
terraform apply -var="environment=dev" -var="instance_type=t3.medium"

# Staging
terraform workspace new staging
terraform apply -var="environment=staging"

# Production
terraform workspace new prod
terraform apply -var="environment=prod" -var="instance_type=t3.xlarge"
```

---

## Operations

### Check Service Status

```bash
# SSH into instance
ssh ubuntu@$(terraform output -raw instance_public_ip)

# View all containers
cd /opt/peerprep/terraform_ec2
docker compose -f docker-compose.ec2.yml ps

# View logs (all services)
docker compose -f docker-compose.ec2.yml logs -f

# View logs (specific service)
docker compose -f docker-compose.ec2.yml logs -f frontend
docker compose -f docker-compose.ec2.yml logs -f postgres
```

### Restart Services

```bash
# Restart all services
cd /opt/peerprep/terraform_ec2
docker compose -f docker-compose.ec2.yml restart

# Restart specific service
docker compose -f docker-compose.ec2.yml restart user-service

# Rebuild after code changes
git pull origin prod/ec2-prod
docker compose -f docker-compose.ec2.yml up -d --build
```

### Database Management

**Access PostgreSQL**:
```bash
docker compose -f docker-compose.ec2.yml exec postgres psql -U peerprep -d question_db
```

**Backup databases**:
```bash
# Backup all databases
docker compose -f docker-compose.ec2.yml exec -T postgres pg_dumpall -U peerprep > backup_$(date +%Y%m%d).sql

# Restore
cat backup_20241022.sql | docker compose -f docker-compose.ec2.yml exec -T postgres psql -U peerprep
```

**Access Redis**:
```bash
# Connect to Redis CLI
docker compose -f docker-compose.ec2.yml exec redis redis-cli

# Select different DB indexes
SELECT 0  # Matching service
SELECT 1  # Collaboration service
SELECT 2  # Chat service
```

### Update Application Code

```bash
# SSH into instance
ssh ubuntu@$(terraform output -raw instance_public_ip)

cd /opt/peerprep
git pull origin prod/ec2-prod

cd terraform_ec2
docker compose -f docker-compose.ec2.yml up -d --build

# Watch services restart
docker compose -f docker-compose.ec2.yml ps
```

### View Resource Usage

```bash
# Container resource usage
docker stats

# System resource usage
htop  # or: top

# Disk usage
df -h
docker system df
```

---

## Monitoring & Logs

### Application Logs

```bash
# Cloud-init bootstrap log
tail -f /var/log/cloud-init-output.log

# Setup log (created by user_data.sh)
tail -f /var/log/peerprep-setup.log

# Docker container logs
cd /opt/peerprep/terraform_ec2
docker compose -f docker-compose.ec2.yml logs -f
```

### Health Checks

All services have health check endpoints:

```bash
# From inside EC2
curl http://localhost/health                    # Frontend
curl http://question-service:8000/health       # Question service
curl http://user-service:8000/health          # User service
# ... etc

# From outside (if port exposed)
curl http://$(terraform output -raw instance_public_ip)/health
```

### AWS Systems Manager Session Manager (No SSH Key Needed!)

```bash
# Connect without SSH key
aws ssm start-session --target $(terraform output -raw instance_id) --region us-east-1

# Run commands
aws ssm send-command \
  --instance-ids $(terraform output -raw instance_id) \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /opt/peerprep/terraform_ec2 && docker compose ps"]' \
  --region us-east-1
```

---

## Troubleshooting

### Services not starting?

```bash
# Check bootstrap progress
tail -f /var/log/cloud-init-output.log

# Check if Docker is running
systemctl status docker

# Check if databases are healthy
docker compose -f docker-compose.ec2.yml ps
docker compose -f docker-compose.ec2.yml logs postgres redis

# Check environment variables
cat /opt/peerprep/.env.ec2
```

### Out of memory?

```bash
# Check memory usage
free -h

# View per-container memory
docker stats

# Solutions:
# 1. Upgrade to t3.xlarge (16GB)
# 2. Add swap space:
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Database connection errors?

```bash
# Check if PostgreSQL is ready
docker compose -f docker-compose.ec2.yml exec postgres pg_isready -U peerprep

# Check if databases exist
docker compose -f docker-compose.ec2.yml exec postgres psql -U peerprep -d postgres -c '\l'

# Recreate databases
docker compose -f docker-compose.ec2.yml exec postgres psql -U peerprep -d postgres <<EOF
CREATE DATABASE question_db;
CREATE DATABASE user_db;
CREATE DATABASE history_db;
CREATE DATABASE matching_db;
EOF
```

### Cannot access application from browser?

```bash
# Check security group allows port 80
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id) \
  --query 'SecurityGroups[0].IpPermissions'

# Check frontend is running
curl http://localhost -v  # from inside EC2

# Check Elastic IP is attached
terraform output instance_public_ip
```

---

## Scaling & Migration Path

This EC2 setup is perfect for:
- ✅ Development & staging environments
- ✅ MVPs and small production workloads (<1000 concurrent users)
- ✅ Cost-conscious deployments

**When to migrate to managed services**:
- Growing to >5000 concurrent users
- Need high availability (99.9%+ uptime)
- Need automatic failover
- Need database read replicas
- Team prefers managed infrastructure

**Easy migration path**:
1. Export data from EC2 PostgreSQL → RDS PostgreSQL
2. Export data from EC2 Redis → ElastiCache Redis
3. Update `.env.prod` with RDS/ElastiCache endpoints
4. Deploy to ECS with `docker-compose.prod.yml`

---

## Cost Management

### Monthly Cost Breakdown (us-east-1)

| Resource             | Cost      | Notes                            |
|----------------------|-----------|----------------------------------|
| EC2 t3.large         | ~$60      | ~$35 with 1-year reserved        |
| EBS 30GB gp3         | ~$3       | Scales with storage needs        |
| Elastic IP           | Free      | Free while attached to instance  |
| Data transfer (out)  | ~$5-10    | Depends on traffic               |
| **Total**            | **~$68**  | **~$43 with reserved instance**  |

### Cost Optimization Tips

1. **Use Reserved Instances**: Save 40-60% for committed 1-3 year usage
2. **Savings Plans**: Flexible alternative to reserved instances
3. **Spot Instances**: Save 70-90% for non-critical dev/test (not recommended for production)
4. **Right-size**: Start with t3.medium, monitor, scale up only if needed
5. **Schedule downtime**: Stop instance during off-hours for dev/staging

```bash
# Stop instance (keeps data, stops billing for compute)
terraform apply -var="instance_type=t3.nano" -replace=aws_instance.peerprep

# Resume
terraform apply -var="instance_type=t3.large"
```

---

## Security Best Practices

### ✅ Implemented

- [x] IMDSv2 required (prevents SSRF attacks)
- [x] Encrypted root volume
- [x] IAM roles (no hardcoded credentials)
- [x] Security group restricts SSH to specific IP
- [x] Secrets can be stored in SSM Parameter Store
- [x] Systems Manager Session Manager (no SSH key exposure)

### 🔒 Additional Recommendations

**For Production**:

1. **Enable SSL/TLS**:
   ```bash
   # Use Let's Encrypt + Certbot
   apt-get install certbot python3-certbot-nginx
   certbot --nginx -d yourdomain.com
   ```

2. **Add CloudFront CDN**:
   - Reduces latency
   - DDoS protection
   - Free SSL certificate

3. **Enable VPC Flow Logs**:
   ```hcl
   # In main.tf, add:
   resource "aws_flow_log" "peerprep" {
     vpc_id          = data.aws_vpc.selected.id
     traffic_type    = "ALL"
     iam_role_arn    = aws_iam_role.flow_logs.arn
     log_destination = aws_cloudwatch_log_group.flow_logs.arn
   }
   ```

4. **Regular Security Updates**:
   ```bash
   # Add to cron (weekly updates)
   crontab -e
   0 2 * * 0 apt-get update && apt-get upgrade -y && docker system prune -af
   ```

5. **Backup Strategy**:
   - Use AWS Backup or
   - Create AMI snapshots weekly
   - Export database dumps to S3

---

## Cleanup

To destroy all infrastructure:

```bash
# Stop all containers first (optional, for clean shutdown)
ssh ubuntu@$(terraform output -raw instance_public_ip) \
  "cd /opt/peerprep/terraform_ec2 && docker compose -f docker-compose.ec2.yml down -v"

# Destroy all Terraform resources
terraform destroy

# Type 'yes' when prompted
```

This will delete:
- EC2 instance (including all data!)
- Elastic IP
- Security group
- IAM roles

**⚠️ Warning**: This is permanent! Backup your databases first if needed.

---

## Support & Contributing

- **Issues**: Report bugs or request features in the main repo
- **Docs**: See `/terraform` for ECS/managed service deployment
- **Team**: @CS3219-AY2526Sem1/cs3219-ay2526s1-project-g19

---

## FAQ

**Q: Can I run this on a free tier t2.micro?**
A: No, 1GB RAM is insufficient. Minimum t3.medium (4GB) required.

**Q: How do I add HTTPS/SSL?**
A: See "Security Best Practices" → Enable SSL/TLS with Certbot.

**Q: Can I use this for production?**
A: Yes, for small-to-medium workloads (<1000 concurrent users). For larger scale, migrate to ECS + RDS + ElastiCache.

**Q: How do I add more replicas/scale horizontally?**
A: This is a single-instance setup. For horizontal scaling, use the ECS deployment in `/terraform`.

**Q: What if I want to use Amazon Linux instead of Ubuntu?**
A: Change the `data.aws_ami.ubuntu` filter in `main.tf` to Amazon Linux 2023 AMI.

**Q: Can I share the database across all services?**
A: Technically yes, but using separate databases per service is better for:
  - Data isolation
  - Independent migrations
  - Security (limit blast radius)
  - Future scalability

**Q: How do I enable CloudWatch monitoring?**
A: Add CloudWatch agent via user_data or use AWS Container Insights.

---

## Next Steps

1. ✅ Deploy to EC2 with this guide
2. 🔒 Add SSL/TLS for HTTPS
3. 📊 Set up CloudWatch monitoring/alerts
4. 🚀 Add CI/CD pipeline (GitHub Actions → Deploy to EC2)
5. 📈 When ready to scale: Migrate to `/terraform` (ECS + managed services)

Happy deploying! 🚀
