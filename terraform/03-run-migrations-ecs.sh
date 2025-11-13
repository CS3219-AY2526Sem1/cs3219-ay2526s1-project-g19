#!/bin/bash
# =============================================================================
# Run Database Migrations via ECS Tasks
# =============================================================================
# This script runs migrations from within ECS (inside the VPC)
# This works even when RDS is not publicly accessible
# =============================================================================

set -e

echo "========================================"
echo "PeerPrep Database Migrations (via ECS)"
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
PROJECT_NAME="peerprep"
ENVIRONMENT="prod"
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"

# Services with databases
DB_SERVICES=("user-service" "question-service" "history-service")

echo -e "${BLUE}Running migrations via ECS tasks...${NC}"
echo "This runs migrations from within the VPC where RDS is accessible."
echo ""

# -----------------------------------------------------------------------------
# Get Task Definition Information
# -----------------------------------------------------------------------------
echo "Getting task definition information..."

for SERVICE in "${DB_SERVICES[@]}"; do
    SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}"

    echo ""
    echo "=========================================="
    echo "Service: $SERVICE"
    echo "=========================================="

    # Get the task definition ARN from the service
    TASK_DEF_ARN=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" \
        --query 'services[0].taskDefinition' \
        --output text 2>/dev/null)

    if [ -z "$TASK_DEF_ARN" ] || [ "$TASK_DEF_ARN" == "None" ]; then
        echo -e "${RED}✗ Could not find service $SERVICE_NAME${NC}"
        continue
    fi

    echo "Task Definition: $TASK_DEF_ARN"

    # Get subnet IDs and security group from the service
    SERVICE_INFO=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" \
        --query 'services[0].networkConfiguration.awsvpcConfiguration' \
        --output json)

    SUBNETS=$(echo "$SERVICE_INFO" | jq -r '.subnets | join(",")')
    SECURITY_GROUPS=$(echo "$SERVICE_INFO" | jq -r '.securityGroups | join(",")')

    if [ -z "$SUBNETS" ] || [ "$SUBNETS" == "null" ]; then
        echo -e "${RED}✗ Could not get network configuration${NC}"
        continue
    fi

    echo "Subnets: $SUBNETS"
    echo "Security Groups: $SECURITY_GROUPS"
    echo ""

    # Run migration task
    echo "Running migration task..."

    TASK_ARN=$(aws ecs run-task \
        --cluster "$CLUSTER_NAME" \
        --task-definition "$TASK_DEF_ARN" \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}" \
        --overrides "$(jq -n --arg name "$SERVICE" \
            '{containerOverrides: [{name: $name, command: ["python", "manage.py", "migrate", "--noinput"]}]}' )" \
        --region "$AWS_REGION" \
        --query 'tasks[0].taskArn' \
        --output text)


    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
        echo -e "${RED}✗ Failed to start migration task${NC}"
        continue
    fi

    echo "Task ARN: $TASK_ARN"
    echo "Waiting for task to complete..."

    # Wait for task to complete
    aws ecs wait tasks-stopped \
        --cluster "$CLUSTER_NAME" \
        --tasks "$TASK_ARN" \
        --region "$AWS_REGION"

    # Check exit code
    EXIT_CODE=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$TASK_ARN" \
        --region "$AWS_REGION" \
        --query 'tasks[0].containers[0].exitCode' \
        --output text)

    if [ "$EXIT_CODE" == "0" ]; then
        echo -e "${GREEN}✓ Migrations completed successfully${NC}"
    else
        echo -e "${RED}✗ Migrations failed with exit code: $EXIT_CODE${NC}"
        echo ""
        echo "View logs with:"
        echo "  aws logs tail /ecs/${PROJECT_NAME}-${ENVIRONMENT} --follow --region $AWS_REGION"
    fi
done

echo ""
echo "========================================"
echo -e "${GREEN}✓ Migration process completed${NC}"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Verify deployment: ./04-verify-deployment.sh"
echo "  2. Check logs: aws logs tail /ecs/${PROJECT_NAME}-${ENVIRONMENT} --follow --region $AWS_REGION"
echo ""
