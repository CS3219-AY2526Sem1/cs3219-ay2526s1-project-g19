#!/bin/bash
# =============================================================================
# Deploy Infrastructure with Terraform
# =============================================================================
# This script runs terraform plan and apply with proper checks
# =============================================================================

set -e

echo "========================================"
echo "PeerPrep Infrastructure Deployment"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")"

# -----------------------------------------------------------------------------
# 1. Terraform Init
# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/4] Initializing Terraform...${NC}"
terraform init -upgrade
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# -----------------------------------------------------------------------------
# 2. Terraform Validate
# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/4] Validating Terraform Configuration...${NC}"
terraform validate
echo -e "${GREEN}✓ Configuration is valid${NC}"
echo ""

# -----------------------------------------------------------------------------
# 3. Terraform Plan
# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/4] Creating Terraform Plan...${NC}"
echo ""
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}IMPORTANT: Review the plan above carefully!${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""
echo "The plan will create/modify:"
echo "  - VPC with public/private subnets"
echo "  - 4 RDS PostgreSQL instances"
echo "  - 3 ElastiCache Redis clusters"
echo "  - Application Load Balancer"
echo "  - ECS Cluster with 7 services"
echo "  - Security groups and networking"
echo ""

# Ask for confirmation
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo ""
    echo -e "${RED}Deployment cancelled by user${NC}"
    echo "To apply later, run: terraform apply tfplan"
    exit 0
fi

# -----------------------------------------------------------------------------
# 4. Terraform Apply
# -----------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[4/4] Applying Terraform Configuration...${NC}"
echo "This may take 15-30 minutes..."
echo ""

terraform apply tfplan

echo ""
echo "========================================"
echo -e "${GREEN}✓ Infrastructure deployed successfully!${NC}"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# 5. Display Outputs
# -----------------------------------------------------------------------------
echo "Getting terraform outputs..."
echo ""

# Check if outputs exist
if terraform output &> /dev/null; then
    echo "Key Infrastructure Details:"
    echo ""

    # VPC
    if terraform output vpc_id &> /dev/null; then
        echo "VPC:"
        echo "  VPC ID: $(terraform output -raw vpc_id 2>/dev/null || echo 'N/A')"
        echo ""
    fi

    # RDS
    echo "RDS Database Endpoints:"
    terraform output -json | jq -r '
        to_entries[] |
        select(.key | contains("db_endpoint")) |
        "  \(.key): \(.value.value)"
    ' 2>/dev/null || echo "  (Check terraform output for database endpoints)"
    echo ""

    # Redis
    echo "Redis Endpoints:"
    terraform output -json | jq -r '
        to_entries[] |
        select(.key | contains("redis_endpoint")) |
        "  \(.key): \(.value.value)"
    ' 2>/dev/null || echo "  (Check terraform output for redis endpoints)"
    echo ""

    # ALB
    if terraform output alb_dns_name &> /dev/null; then
        ALB_DNS=$(terraform output -raw alb_dns_name)
        echo "Application Load Balancer:"
        echo "  DNS: $ALB_DNS"
        echo "  URL: http://$ALB_DNS"
        echo ""
    fi

    # ECS
    if terraform output ecs_cluster_name &> /dev/null; then
        echo "ECS Cluster:"
        echo "  Name: $(terraform output -raw ecs_cluster_name)"
        echo ""
    fi
fi

echo ""
echo "========================================"
echo "Next Steps:"
echo "========================================"
echo ""
echo "1. Build and push Docker images:"
echo "   ./01-build-and-push-images.sh"
echo ""
echo "2. Wait 2-3 minutes for ECS services to pull images and start"
echo ""
echo "3. Check service status:"
echo "   aws ecs list-services --cluster peerprep-prod-cluster --region ap-southeast-1"
echo ""
echo "4. Run database migrations:"
echo "   ./03-run-migrations.sh"
echo ""
echo "5. Verify deployment:"
echo "   ./04-verify-deployment.sh"
echo ""
echo "6. View logs:"
echo "   aws logs tail /ecs/peerprep-prod --follow --region ap-southeast-1"
echo ""

# Save outputs to file for later use
echo "Saving outputs to terraform-outputs.json..."
terraform output -json > terraform-outputs.json
echo -e "${GREEN}✓ Outputs saved to terraform-outputs.json${NC}"
echo ""
