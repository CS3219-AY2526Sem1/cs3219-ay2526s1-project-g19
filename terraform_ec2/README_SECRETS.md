# Simple Secret Management (KISS)

## Overview

**Simple workflow:**
1. Local: `secrets/.env` → Upload to AWS SSM
2. EC2: Download from AWS SSM → `/opt/peerprep/.env` for docker-compose

---

## Quick Start

### Step 1: Create secrets/.env

```bash
# Copy example
cp secrets/.env.example secrets/.env

# Generate secure values
python3 -c "import secrets; print('DB_PASSWORD:', secrets.token_urlsafe(32))"
python3 -c "import secrets; print('SECRET_KEY:', secrets.token_urlsafe(50))"

# Edit secrets/.env with the generated values
nano secrets/.env
```

### Step 2: Upload to AWS SSM

```bash
cd terraform_ec2
./scripts/setup-ssm-secrets.sh
```

That's it! The entire `.env` file is now stored securely in AWS SSM Parameter Store.

### Step 3: Enable SSM in Terraform

Edit `terraform_ec2/terraform.tfvars`:

```hcl
use_ssm_secrets = true
```

### Step 4: Deploy

```bash
cd terraform_ec2
terraform apply
```

EC2 will automatically fetch `secrets/.env` from AWS SSM on boot.

---

## Update Secrets

### Update locally and re-upload:

```bash
# Edit secrets/.env
nano secrets/.env

# Upload to AWS
cd terraform_ec2
./scripts/setup-ssm-secrets.sh

# Refresh on EC2
ssh ubuntu@your-ec2-ip
sudo /opt/peerprep/scripts/update-secrets.sh
```

---

## Architecture

```
Local Machine                AWS SSM                    EC2 Instance
─────────────                ───────                    ────────────

secrets/.env
     │
     │ setup-ssm-secrets.sh
     │ (uploads entire file)
     ├────────────────────────>
     │                         /peerprep/ec2-prod/
     │                         ENV_FILE
     │                         (encrypted)
     │                              │
     │                              │ fetch-secrets.sh (on boot)
     │                              ├──────────────────────────>
     │                              │                           /opt/peerprep/.env
     │                              │                                │
     │                              │                                v
     │                              │                           docker-compose
```

---

## Files

- `secrets/.env` - Your actual secrets (gitignored, local only)
- `secrets/.env.example` - Template for reference
- `terraform_ec2/scripts/setup-ssm-secrets.sh` - Upload to AWS
- `terraform_ec2/scripts/fetch-secrets.sh` - Download on EC2
- `terraform_ec2/scripts/update-secrets.sh` - Refresh on EC2
- `terraform_ec2/scripts/update-my-ip.sh` - Update security group with your current IP

---

## Security

- ✅ Entire `.env` encrypted in AWS SSM (SecureString)
- ✅ Never in Terraform state or user_data
- ✅ `secrets/.env` is gitignored
- ✅ IAM-based access control
- ✅ CloudTrail audit logs
- ✅ Free (AWS SSM standard tier)

---

## That's it!

No complex parsing, no individual parameter management. Just upload your `.env` file and it works.
