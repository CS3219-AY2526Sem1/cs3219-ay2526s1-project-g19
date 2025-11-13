#!/bin/bash
# =============================================================================
# Pre-Deployment Validation Script
# =============================================================================
# Run this script BEFORE terraform apply to validate all prerequisites
# =============================================================================

set -e

echo "========================================"
echo "PeerPrep Pre-Deployment Validation"
echo "========================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

# -----------------------------------------------------------------------------
# Function: Check command exists
# -----------------------------------------------------------------------------
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is NOT installed"
        FAILED=1
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Function: Check terraform variable
# -----------------------------------------------------------------------------
check_tfvar() {
    local var_name=$1
    local var_value=$2
    local default_bad=$3

    if [ "$var_value" == "$default_bad" ]; then
        echo -e "${RED}✗${NC} $var_name is still using default/insecure value: $var_value"
        FAILED=1
        return 1
    else
        echo -e "${GREEN}✓${NC} $var_name is set to a custom value"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# 1. Check Required Tools
# -----------------------------------------------------------------------------
echo "1. Checking Required Tools..."
check_command "aws"
check_command "terraform"
check_command "docker"
check_command "jq"
echo ""

# -----------------------------------------------------------------------------
# 2. Check AWS Credentials
# -----------------------------------------------------------------------------
echo "2. Checking AWS Credentials..."
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    AWS_USER=$(aws sts get-caller-identity --query "Arn" --output text)
    echo -e "${GREEN}✓${NC} AWS credentials are valid"
    echo "  Account ID: $ACCOUNT_ID"
    echo "  User/Role: $AWS_USER"
else
    echo -e "${RED}✗${NC} AWS credentials are NOT configured properly"
    echo "  Run: aws configure"
    FAILED=1
fi
echo ""

# -----------------------------------------------------------------------------
# 3. Check AWS Region
# -----------------------------------------------------------------------------
echo "3. Checking AWS Region..."
REGION=$(aws configure get region)
if [ -n "$REGION" ]; then
    echo -e "${GREEN}✓${NC} AWS region is set to: $REGION"
else
    echo -e "${YELLOW}⚠${NC} AWS region not explicitly set, will use terraform default"
fi
echo ""

# -----------------------------------------------------------------------------
# 4. Check Terraform Configuration
# -----------------------------------------------------------------------------
echo "4. Checking Terraform Configuration..."
cd "$(dirname "$0")"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}✗${NC} terraform.tfvars not found!"
    FAILED=1
else
    echo -e "${GREEN}✓${NC} terraform.tfvars exists"

    # Extract critical variables
    DB_PASSWORD=$(grep 'db_password' terraform.tfvars | cut -d'"' -f2)
    SECRET_KEY=$(grep 'secret_key' terraform.tfvars | cut -d'"' -f2)

    # # Check if secrets are still default values
    # check_tfvar "db_password" "$DB_PASSWORD" "CHANGE_ME_SECURE_PASSWORD_HERE"
    # check_tfvar "secret_key" "$SECRET_KEY" "CHANGE_ME_SECURE_SECRET_KEY_HERE"
fi
echo ""

# -----------------------------------------------------------------------------
# 5. Validate Terraform Syntax
# -----------------------------------------------------------------------------
echo "5. Validating Terraform Syntax..."
if terraform init -backend=false &> /dev/null; then
    echo -e "${GREEN}✓${NC} Terraform initialized (validation mode)"
    if terraform validate &> /dev/null; then
        echo -e "${GREEN}✓${NC} Terraform configuration is valid"
    else
        echo -e "${RED}✗${NC} Terraform validation failed"
        terraform validate
        FAILED=1
    fi
else
    echo -e "${RED}✗${NC} Terraform initialization failed"
    FAILED=1
fi
echo ""

# -----------------------------------------------------------------------------
# 6. Check Docker Engine
# -----------------------------------------------------------------------------
echo "6. Checking Docker Engine..."
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker engine is running"
else
    echo -e "${RED}✗${NC} Docker engine is NOT running"
    echo "  Start Docker Desktop or docker daemon"
    FAILED=1
fi
echo ""

# -----------------------------------------------------------------------------
# 7. Check Service Dockerfiles
# -----------------------------------------------------------------------------
echo "7. Checking Service Dockerfiles..."
SERVICES=("user_service" "question_service" "matching_service" "history_service" "collaboration_service" "chat_service" "frontend")
cd ..

for service in "${SERVICES[@]}"; do
    if [ -f "$service/Dockerfile" ]; then
        echo -e "${GREEN}✓${NC} $service/Dockerfile exists"
    else
        echo -e "${RED}✗${NC} $service/Dockerfile NOT found"
        FAILED=1
    fi
done
echo ""

# -----------------------------------------------------------------------------
# 8. Check Docker Entrypoint Scripts
# -----------------------------------------------------------------------------
echo "8. Checking Docker Entrypoint Scripts..."
DB_SERVICES=("user_service" "question_service" "history_service")

for service in "${DB_SERVICES[@]}"; do
    if [ -f "$service/docker-entrypoint.sh" ]; then
        echo -e "${GREEN}✓${NC} $service/docker-entrypoint.sh exists"

        # Check if entrypoint has DB_HOST variable
        if grep -q 'DB_HOST' "$service/docker-entrypoint.sh"; then
            echo -e "${GREEN}  ✓${NC} Entrypoint handles DB_HOST environment variable"
        else
            echo -e "${YELLOW}  ⚠${NC} Entrypoint may not handle DB_HOST properly"
        fi
    else
        echo -e "${YELLOW}⚠${NC} $service/docker-entrypoint.sh NOT found (may not be needed)"
    fi
done
echo ""

# -----------------------------------------------------------------------------
# 9. Check ECR Repository Access
# -----------------------------------------------------------------------------
echo "9. Checking ECR Repository Access..."
if aws ecr describe-repositories --region "${REGION:-ap-southeast-1}" &> /dev/null; then
    echo -e "${GREEN}✓${NC} ECR access is configured"
    echo "  Use 'aws ecr describe-repositories' to see existing repositories"
else
    echo -e "${YELLOW}⚠${NC} Cannot access ECR (will be created by terraform)"
fi
echo ""

# -----------------------------------------------------------------------------
# 10. Check for .gitignore for secrets
# -----------------------------------------------------------------------------
echo "10. Checking .gitignore for Secrets..."
cd "$(dirname "$0")"

if [ -f "../.gitignore" ]; then
    if grep -q "terraform.tfvars" ../.gitignore || grep -q "*.tfvars" ../.gitignore; then
        echo -e "${GREEN}✓${NC} terraform.tfvars is in .gitignore"
    else
        echo -e "${RED}✗${NC} terraform.tfvars NOT in .gitignore - SECURITY RISK!"
        echo "  Add 'terraform.tfvars' to .gitignore"
        FAILED=1
    fi
else
    echo -e "${YELLOW}⚠${NC} .gitignore not found"
fi
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All pre-deployment checks PASSED!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review terraform.tfvars one more time"
    echo "  2. Run: ./01-build-and-push-images.sh"
    echo "  3. Run: ./02-deploy-infrastructure.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks FAILED!${NC}"
    echo ""
    echo "Please fix the issues above before proceeding."
    echo ""
    exit 1
fi
