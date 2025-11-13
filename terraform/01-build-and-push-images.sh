#!/bin/bash
# =============================================================================
# Build and Push Docker Images to ECR
# =============================================================================
# This script builds all service Docker images and pushes them to ECR
#
# ORDER: Run this AFTER "terraform apply" creates ECR repositories
#
# If you run this BEFORE terraform apply, it will create ECR repos,
# causing terraform to fail with "repository already exists" error
# =============================================================================

set -e

echo "========================================"
echo "PeerPrep Docker Image Build & Push"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
AWS_REGION=${AWS_REGION:-ap-southeast-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROJECT_NAME="peerprep"
ENVIRONMENT="prod"
ECR_BASE_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Service definitions (macOS bash 3.2 compatible)
SERVICE_NAMES=(
    "user-service"
    "question-service"
    "matching-service"
    "history-service"
    "collaboration-service"
    "chat-service"
    "frontend"
)

SERVICE_DIRS=(
    "user_service"
    "question_service"
    "matching_service"
    "history_service"
    "collaboration_service"
    "chat_service"
    "frontend"
)

# -----------------------------------------------------------------------------
# 1. ECR Login
# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/3] Logging into ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_BASE_URL"
echo -e "${GREEN}✓ Logged into ECR${NC}"
echo ""

# -----------------------------------------------------------------------------
# 2. Build Docker Images
# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/3] Building Docker Images...${NC}"
cd "$(dirname "$0")/.."

# Loop through services
for i in "${!SERVICE_NAMES[@]}"; do
    SERVICE_NAME="${SERVICE_NAMES[$i]}"
    SERVICE_DIR="${SERVICE_DIRS[$i]}"
    IMAGE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE_NAME}"
    FULL_IMAGE_NAME="${ECR_BASE_URL}/${IMAGE_NAME}:latest"

    echo ""
    echo "----------------------------------------"
    echo "Building: $SERVICE_NAME"
    echo "Directory: $SERVICE_DIR"
    echo "Image: $FULL_IMAGE_NAME"
    echo "----------------------------------------"

    if [ ! -d "$SERVICE_DIR" ]; then
        echo -e "${YELLOW}⚠ Warning: Directory $SERVICE_DIR not found, skipping${NC}"
        continue
    fi

    # Build for linux/amd64 platform (required for ECS)
    build_args=(
        --platform linux/amd64
        -t "$IMAGE_NAME:latest"
        -t "$FULL_IMAGE_NAME"
    )

    if [ "$SERVICE_NAME" = "frontend" ]; then
        build_args+=(
            --build-arg "VITE_QUESTION_SERVICE_URL=${VITE_QUESTION_SERVICE_URL:-/question-service-api}"
            --build-arg "VITE_MATCHING_SERVICE_URL=${VITE_MATCHING_SERVICE_URL:-/matching-service-api}"
            --build-arg "VITE_SESSION_SERVICE_URL=${VITE_SESSION_SERVICE_URL:-/session-service-api}"
            --build-arg "VITE_USER_SERVICE_URL=${VITE_USER_SERVICE_URL:-/user-service-api}"
            --build-arg "VITE_COLLABORATION_SERVICE_URL=${VITE_COLLABORATION_SERVICE_URL:-/collaboration-service-api}"
            --build-arg "VITE_CHAT_SERVICE_URL=${VITE_CHAT_SERVICE_URL:-/chat-service-api}"
            --build-arg "VITE_EXECUTION_API=${VITE_EXECUTION_API:-}"
        )
    fi

    docker build \
        "${build_args[@]}" \
        "$SERVICE_DIR"

    echo -e "${GREEN}✓ Built $SERVICE_NAME${NC}"
done

echo ""
echo -e "${GREEN}✓ All images built successfully${NC}"
echo ""

# -----------------------------------------------------------------------------
# 3. Push Docker Images to ECR
# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/3] Pushing Images to ECR...${NC}"

for i in "${!SERVICE_NAMES[@]}"; do
    SERVICE_NAME="${SERVICE_NAMES[$i]}"
    IMAGE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE_NAME}"
    FULL_IMAGE_NAME="${ECR_BASE_URL}/${IMAGE_NAME}:latest"

    echo ""
    echo "Pushing: $FULL_IMAGE_NAME"

    # Check if ECR repository exists
    if ! aws ecr describe-repositories \
        --repository-names "$IMAGE_NAME" \
        --region "$AWS_REGION" &> /dev/null; then

        echo -e "${RED}✗ Repository $IMAGE_NAME doesn't exist!${NC}"
        echo "  Run 'terraform apply' first to create ECR repositories"
        exit 1
    fi

    # Push image
    docker push "$FULL_IMAGE_NAME"
    echo -e "${GREEN}✓ Pushed $SERVICE_NAME${NC}"
done

echo ""
echo "========================================"
echo -e "${GREEN}✓ All images pushed successfully!${NC}"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# 4. Display Image Information
# -----------------------------------------------------------------------------
echo "ECR Image URIs:"
for i in "${!SERVICE_NAMES[@]}"; do
    SERVICE_NAME="${SERVICE_NAMES[$i]}"
    IMAGE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE_NAME}"
    FULL_IMAGE_NAME="${ECR_BASE_URL}/${IMAGE_NAME}:latest"
    echo "  $SERVICE_NAME: $FULL_IMAGE_NAME"
done

echo ""
echo "Next steps:"
echo "  1. Wait 2-3 minutes for ECS services to start and pull images"
echo "  2. Run: ./03-run-migrations.sh"
echo "  3. Run: ./04-verify-deployment.sh"
echo ""
