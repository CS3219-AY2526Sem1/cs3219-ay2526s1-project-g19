#!/bin/bash
# =============================================================================
# Force ECS Service Updates
# =============================================================================
# Use this after pushing new Docker images to force ECS to pull latest images
# =============================================================================

set -e

echo "========================================"
echo "Force ECS Service Update"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

AWS_REGION=${AWS_REGION:-ap-southeast-1}
PROJECT_NAME="peerprep"
ENVIRONMENT="prod"
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"

# Services to update
SERVICES=(
    "user-service"
    "question-service"
    "matching-service"
    "history-service"
    "collaboration-service"
    "chat-service"
    "frontend"
)

echo -e "${BLUE}Forcing service updates to pull latest images...${NC}"
echo ""

for SERVICE in "${SERVICES[@]}"; do
    SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}"

    echo "Updating: $SERVICE_NAME"

    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --force-new-deployment \
        --region "$AWS_REGION" \
        --query 'service.{Service:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' \
        --output table

    echo -e "${GREEN}✓ Update triggered for $SERVICE${NC}"
    echo ""
done

echo "========================================"
echo -e "${GREEN}✓ All service updates triggered!${NC}"
echo "========================================"
echo ""
echo "Services will now pull the latest images and restart."
echo "This takes 2-3 minutes."
echo ""
echo "Monitor progress:"
echo "  aws logs tail /ecs/${PROJECT_NAME}-${ENVIRONMENT} --follow --region $AWS_REGION"
echo ""
