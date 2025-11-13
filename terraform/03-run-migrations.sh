#!/bin/bash
# =============================================================================
# Run Database Migrations
# =============================================================================
# This script runs Django migrations for all services with databases
# Run this AFTER terraform apply and ECS services are running
# =============================================================================

set -e

echo "========================================"
echo "PeerPrep Database Migrations"
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
# Configuration
# -----------------------------------------------------------------------------
AWS_REGION=${AWS_REGION:-ap-southeast-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
PROJECT_NAME="peerprep"
ENVIRONMENT="prod"

# Check if terraform outputs exist
if [ ! -f "terraform-outputs.json" ]; then
    echo -e "${YELLOW}⚠ terraform-outputs.json not found${NC}"
    echo "Fetching terraform outputs..."
    terraform output -json > terraform-outputs.json
fi

# Extract database endpoints
echo "Extracting database connection information..."

# Get database password from tfvars
DB_PASSWORD=$(grep 'db_password' terraform.tfvars | cut -d'"' -f2)
DB_USERNAME="peerprep_admin"

# Parse endpoints from terraform output
USER_DB_ENDPOINT=$(cat terraform-outputs.json | jq -r '.user_db_endpoint.value // empty')
QUESTION_DB_ENDPOINT=$(cat terraform-outputs.json | jq -r '.question_db_endpoint.value // empty')
HISTORY_DB_ENDPOINT=$(cat terraform-outputs.json | jq -r '.history_db_endpoint.value // empty')

# Fallback: try to get from AWS RDS directly if terraform output doesn't have it
if [ -z "$USER_DB_ENDPOINT" ]; then
    echo "Fetching database endpoints from AWS RDS..."
    USER_DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "${PROJECT_NAME}-${ENVIRONMENT}-user-postgres" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text 2>/dev/null || echo "")
    QUESTION_DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "${PROJECT_NAME}-${ENVIRONMENT}-question-postgres" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text 2>/dev/null || echo "")
    HISTORY_DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "${PROJECT_NAME}-${ENVIRONMENT}-history-postgres" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text 2>/dev/null || echo "")
fi

# Service to database mapping (macOS bash 3.2 compatible)
DB_SERVICES=("user-service" "question-service" "history-service")
DB_ENDPOINTS=("$USER_DB_ENDPOINT" "$QUESTION_DB_ENDPOINT" "$HISTORY_DB_ENDPOINT")
DB_NAMES=("user_db" "question_db" "history_db")

# -----------------------------------------------------------------------------
# ECR Login
# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/3] Logging into ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_BASE_URL"
echo -e "${GREEN}✓ Logged into ECR${NC}"
echo ""

# -----------------------------------------------------------------------------
# Run Migrations
# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/3] Running Database Migrations...${NC}"
echo ""

for i in "${!DB_SERVICES[@]}"; do
    SERVICE="${DB_SERVICES[$i]}"
    DB_ENDPOINT="${DB_ENDPOINTS[$i]}"
    DB_NAME="${DB_NAMES[$i]}"
    DB_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_ENDPOINT}:5432/${DB_NAME}"
    IMAGE_NAME="${ECR_BASE_URL}/${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}:latest"

    echo "----------------------------------------"
    echo "Service: $SERVICE"
    echo "----------------------------------------"

    # Check if database URL is valid
    if [[ "$DB_URL" == *"None"* ]] || [[ "$DB_URL" == *"::"* ]] || [ -z "$DB_ENDPOINT" ]; then
        echo -e "${RED}✗ Invalid database URL for $SERVICE${NC}"
        echo "  URL: $DB_URL"
        echo "  Skipping migrations for this service"
        echo ""
        continue
    fi

    echo "Database URL: ${DB_URL%%:*}://***:***@${DB_URL##*@}"
    echo "Image: $IMAGE_NAME"
    echo ""

    # Pull latest image
    echo "Pulling latest image..."
    docker pull "$IMAGE_NAME"

    # Run migrations
    echo "Running migrations..."
    if docker run --rm --platform linux/amd64 \
        -e DATABASE_URL="$DB_URL" \
        -e DB_HOST="$DB_ENDPOINT" \
        -e DB_PORT="5432" \
        -e DB_NAME="$DB_NAME" \
        -e DB_USER="$DB_USERNAME" \
        -e DB_PASSWORD="$DB_PASSWORD" \
        "$IMAGE_NAME" \
        python manage.py migrate --noinput; then
        echo -e "${GREEN}✓ Migrations completed for $SERVICE${NC}"
    else
        echo -e "${RED}✗ Migrations failed for $SERVICE${NC}"
        echo "  Check the error above for details"
    fi

    echo ""
done

echo "========================================"
echo -e "${GREEN}✓ Migration process completed${NC}"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/3] Verifying Database Connections...${NC}"
echo ""

for i in "${!DB_SERVICES[@]}"; do
    SERVICE="${DB_SERVICES[$i]}"
    DB_ENDPOINT="${DB_ENDPOINTS[$i]}"
    DB_NAME="${DB_NAMES[$i]}"
    DB_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_ENDPOINT}:5432/${DB_NAME}"
    IMAGE_NAME="${ECR_BASE_URL}/${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}:latest"

    if [[ "$DB_URL" == *"None"* ]] || [[ "$DB_URL" == *"::"* ]] || [ -z "$DB_ENDPOINT" ]; then
        continue
    fi

    echo -n "Testing $SERVICE database connection... "
    if docker run --rm --platform linux/amd64 \
        -e DATABASE_URL="$DB_URL" \
        -e DB_HOST="$DB_ENDPOINT" \
        -e DB_PORT="5432" \
        -e DB_NAME="$DB_NAME" \
        -e DB_USER="$DB_USERNAME" \
        -e DB_PASSWORD="$DB_PASSWORD" \
        "$IMAGE_NAME" \
        python -c "import django; django.setup(); from django.db import connection; connection.ensure_connection(); print('OK')" &> /dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${YELLOW}⚠ Could not verify connection${NC}"
    fi
done

echo ""
echo "========================================"
echo "Next Steps:"
echo "========================================"
echo ""
echo "1. Check ECS service status:"
echo "   aws ecs describe-services --cluster ${PROJECT_NAME}-${ENVIRONMENT}-cluster \\"
echo "     --services ${PROJECT_NAME}-${ENVIRONMENT}-user-service \\"
echo "     --region $AWS_REGION"
echo ""
echo "2. View service logs:"
echo "   aws logs tail /ecs/${PROJECT_NAME}-${ENVIRONMENT} --follow --region $AWS_REGION"
echo ""
echo "3. Run deployment verification:"
echo "   ./04-verify-deployment.sh"
echo ""
