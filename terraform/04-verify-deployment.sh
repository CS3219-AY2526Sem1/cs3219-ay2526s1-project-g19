#!/bin/bash
# =============================================================================
# Verify Deployment
# =============================================================================
# This script verifies that all infrastructure and services are running
# =============================================================================

set -e

echo "========================================"
echo "PeerPrep Deployment Verification"
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

SERVICES=(
    "user-service"
    "question-service"
    "matching-service"
    "history-service"
    "collaboration-service"
    "chat-service"
    "frontend"
)

# Get ALB DNS
if [ -f "terraform-outputs.json" ]; then
    ALB_DNS=$(cat terraform-outputs.json | jq -r '.alb_dns_name.value // empty')
else
    echo "Getting ALB DNS from terraform..."
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
fi

FAILED=0

# -----------------------------------------------------------------------------
# 1. Check VPC
# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/7] Checking VPC...${NC}"

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo -e "${GREEN}✓${NC} VPC exists: $VPC_ID"
else
    echo -e "${RED}✗${NC} VPC not found"
    FAILED=1
fi
echo ""

# -----------------------------------------------------------------------------
# 2. Check RDS Instances
# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/7] Checking RDS Databases...${NC}"

DB_SERVICES=("user" "question" "matching" "history")
for SERVICE in "${DB_SERVICES[@]}"; do
    DB_ID="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}-postgres"
    DB_STATUS=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB_ID" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "not-found")

    if [ "$DB_STATUS" == "available" ]; then
        echo -e "${GREEN}✓${NC} ${SERVICE}-db: $DB_STATUS"
    elif [ "$DB_STATUS" == "not-found" ]; then
        echo -e "${RED}✗${NC} ${SERVICE}-db: not found"
        FAILED=1
    else
        echo -e "${YELLOW}⚠${NC} ${SERVICE}-db: $DB_STATUS (waiting...)"
    fi
done
echo ""

# -----------------------------------------------------------------------------
# 3. Check ElastiCache Redis Clusters
# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/7] Checking Redis Clusters...${NC}"

REDIS_SERVICES=("matching" "collab" "chat")
for SERVICE in "${REDIS_SERVICES[@]}"; do
    RG_ID="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}-redis"
    RG_STATUS=$(aws elasticache describe-replication-groups \
        --replication-group-id "$RG_ID" \
        --query 'ReplicationGroups[0].Status' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "not-found")

    if [ "$RG_STATUS" != "not-found" ] && [ "$RG_STATUS" != "None" ]; then
        if [ "$RG_STATUS" == "available" ]; then
            echo -e "${GREEN}✓${NC} ${SERVICE}-redis: $RG_STATUS"
        else
            echo -e "${YELLOW}⚠${NC} ${SERVICE}-redis: $RG_STATUS (waiting...)"
        fi
        continue
    fi

    CACHE_ID="${RG_ID}-001"
    CACHE_STATUS=$(aws elasticache describe-cache-clusters \
        --cache-cluster-id "$CACHE_ID" \
        --query 'CacheClusters[0].CacheClusterStatus' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "not-found")

    if [ "$CACHE_STATUS" == "available" ]; then
        echo -e "${GREEN}✓${NC} ${SERVICE}-redis: $CACHE_STATUS"
    elif [ "$CACHE_STATUS" == "not-found" ]; then
        echo -e "${RED}✗${NC} ${SERVICE}-redis: not found"
        FAILED=1
    else
        echo -e "${YELLOW}⚠${NC} ${SERVICE}-redis: $CACHE_STATUS (waiting...)"
    fi
done
echo ""

# -----------------------------------------------------------------------------
# 4. Check ECS Cluster
# -----------------------------------------------------------------------------
echo -e "${BLUE}[4/7] Checking ECS Cluster...${NC}"

CLUSTER_STATUS=$(aws ecs describe-clusters \
    --clusters "$CLUSTER_NAME" \
    --query 'clusters[0].status' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "not-found")

if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
    RUNNING_TASKS=$(aws ecs describe-clusters \
        --clusters "$CLUSTER_NAME" \
        --query 'clusters[0].runningTasksCount' \
        --output text \
        --region "$AWS_REGION")
    echo -e "${GREEN}✓${NC} ECS Cluster: $CLUSTER_STATUS (Running tasks: $RUNNING_TASKS)"
else
    echo -e "${RED}✗${NC} ECS Cluster: $CLUSTER_STATUS"
    FAILED=1
fi
echo ""

# -----------------------------------------------------------------------------
# 5. Check ECS Services
# -----------------------------------------------------------------------------
echo -e "${BLUE}[5/7] Checking ECS Services...${NC}"

for SERVICE in "${SERVICES[@]}"; do
    SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}"

    SERVICE_INFO=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" 2>/dev/null || echo "")

    if [ -n "$SERVICE_INFO" ]; then
        DESIRED=$(echo "$SERVICE_INFO" | jq -r '.services[0].desiredCount')
        RUNNING=$(echo "$SERVICE_INFO" | jq -r '.services[0].runningCount')
        STATUS=$(echo "$SERVICE_INFO" | jq -r '.services[0].status')

        if [ "$STATUS" == "ACTIVE" ] && [ "$RUNNING" == "$DESIRED" ]; then
            echo -e "${GREEN}✓${NC} $SERVICE: $RUNNING/$DESIRED tasks running"
        elif [ "$STATUS" == "ACTIVE" ]; then
            echo -e "${YELLOW}⚠${NC} $SERVICE: $RUNNING/$DESIRED tasks running (starting up...)"
        else
            echo -e "${RED}✗${NC} $SERVICE: Status=$STATUS, $RUNNING/$DESIRED tasks"
            FAILED=1
        fi
    else
        echo -e "${RED}✗${NC} $SERVICE: not found"
        FAILED=1
    fi
done
echo ""

# -----------------------------------------------------------------------------
# 6. Check Application Load Balancer
# -----------------------------------------------------------------------------
echo -e "${BLUE}[6/7] Checking Application Load Balancer...${NC}"

if [ -n "$ALB_DNS" ]; then
    echo -e "${GREEN}✓${NC} ALB DNS: $ALB_DNS"

    # Check target health for each service
    echo ""
    echo "Checking target group health..."

    for SERVICE in "${SERVICES[@]}"; do
        TG_ARN=$(aws elbv2 describe-target-groups \
            --names "${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}-tg" \
            --query 'TargetGroups[0].TargetGroupArn' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "")

        if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
            HEALTH=$(aws elbv2 describe-target-health \
                --target-group-arn "$TG_ARN" \
                --region "$AWS_REGION" 2>/dev/null || echo "")

            HEALTHY_COUNT=$(echo "$HEALTH" | jq -r '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
            TOTAL_COUNT=$(echo "$HEALTH" | jq -r '.TargetHealthDescriptions | length')

            if [ "$HEALTHY_COUNT" -gt 0 ] && [ "$HEALTHY_COUNT" == "$TOTAL_COUNT" ]; then
                echo -e "  ${GREEN}✓${NC} $SERVICE: $HEALTHY_COUNT/$TOTAL_COUNT targets healthy"
            elif [ "$HEALTHY_COUNT" -gt 0 ]; then
                echo -e "  ${YELLOW}⚠${NC} $SERVICE: $HEALTHY_COUNT/$TOTAL_COUNT targets healthy (some starting...)"
            else
                echo -e "  ${RED}✗${NC} $SERVICE: $HEALTHY_COUNT/$TOTAL_COUNT targets healthy"
            fi
        fi
    done
else
    echo -e "${RED}✗${NC} ALB DNS not found"
    FAILED=1
fi
echo ""

# -----------------------------------------------------------------------------
# 7. Test HTTP Endpoints
# -----------------------------------------------------------------------------
echo -e "${BLUE}[7/7] Testing HTTP Endpoints...${NC}"

if [ -n "$ALB_DNS" ]; then
    # Test frontend
    echo -n "Testing frontend (/)... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}/" --max-time 10 || echo "000")
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "301" ] || [ "$HTTP_CODE" == "302" ]; then
        echo -e "${GREEN}✓ $HTTP_CODE${NC}"
    else
        echo -e "${YELLOW}⚠ $HTTP_CODE${NC}"
    fi

    # Test backend services (if health endpoints exist)
    for SERVICE in "user-service" "question-service" "matching-service" "history-service"; do
        echo -n "Testing $SERVICE (/health)... "
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            "http://${ALB_DNS}/${SERVICE}-api/health" --max-time 10 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" == "200" ]; then
            echo -e "${GREEN}✓ $HTTP_CODE${NC}"
        elif [ "$HTTP_CODE" == "404" ]; then
            echo -e "${YELLOW}⚠ $HTTP_CODE (no health endpoint)${NC}"
        else
            echo -e "${YELLOW}⚠ $HTTP_CODE${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} Cannot test endpoints without ALB DNS"
fi
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Deployment verification PASSED!${NC}"
    echo ""
    echo "Your application is deployed at:"
    echo "  http://$ALB_DNS"
    echo ""
    echo "Useful commands:"
    echo "  View logs:"
    echo "    aws logs tail /ecs/${PROJECT_NAME}-${ENVIRONMENT} --follow --region $AWS_REGION"
    echo ""
    echo "  Check service status:"
    echo "    aws ecs describe-services --cluster $CLUSTER_NAME \\"
    echo "      --services ${PROJECT_NAME}-${ENVIRONMENT}-user-service --region $AWS_REGION"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠ Deployment verification completed with warnings${NC}"
    echo ""
    echo "Some resources may still be starting up."
    echo "Wait a few minutes and run this script again."
    echo ""
    exit 1
fi
