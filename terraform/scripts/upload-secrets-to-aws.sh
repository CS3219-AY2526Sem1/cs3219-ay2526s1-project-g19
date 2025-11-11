#!/bin/bash
# =============================================================================
# Upload .env to AWS Secrets Manager for ECS
# =============================================================================
# Usage: ./scripts/upload-secrets-to-aws.sh [env_file] [environment] [region]
# Example: ./scripts/upload-secrets-to-aws.sh ../.env.prod production us-east-1
# =============================================================================

set -euo pipefail

# Configuration
ENV_FILE="${1:-../.env.prod}"
ENVIRONMENT="${2:-production}"
AWS_REGION="${3:-us-east-1}"
PROJECT_NAME="peerprep"

SECRET_NAME="${PROJECT_NAME}/${ENVIRONMENT}/env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Validation
# =============================================================================

log_info "Uploading .env to AWS Secrets Manager for ECS..."

if [[ ! -f "$ENV_FILE" ]]; then
    log_error "File not found: $ENV_FILE"
    echo ""
    echo "Create the file first (example):"
    echo "  cp .env.sample .env.prod"
    echo "  # Edit .env.prod with production values"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not installed"
    exit 1
fi

if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
    log_error "AWS credentials not configured"
    exit 1
fi

log_success "Found: $ENV_FILE"
log_info "Region: $AWS_REGION"
log_info "Secret Name: $SECRET_NAME"
echo ""

# =============================================================================
# Upload .env file as raw text
# =============================================================================

log_info "Uploading complete .env file to Secrets Manager..."
file_size=$(wc -c < "$ENV_FILE")
if [[ $file_size -gt 65536 ]]; then
    log_error "Secret size exceeds 64KB Secrets Manager limit (current: ${file_size} bytes)"
    exit 1
fi

if aws secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    &> /dev/null; then
    log_info "Secret exists, updating..."
    if ! aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "file://$ENV_FILE" \
        --region "$AWS_REGION" \
        &> /dev/null; then
        log_error "Failed to update secret"
        exit 1
    fi
else
    log_info "Secret not found, creating..."
    if ! aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "PeerPrep ECS ${ENVIRONMENT} environment variables" \
        --secret-string "file://$ENV_FILE" \
        --region "$AWS_REGION" \
        --tags Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENVIRONMENT Key=ManagedBy,Value=Script \
        &> /dev/null; then
        log_error "Failed to create secret"
        exit 1
    fi
fi

log_success "✓ Uploaded to Secrets Manager: $SECRET_NAME"

# =============================================================================
# Verification
# =============================================================================

log_info "Verifying upload..."

ENV_LINES=$(wc -l < "$ENV_FILE" | xargs)
SECRET_LINES=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text | wc -l | xargs)

log_info "Local .env: $ENV_LINES lines"
log_info "Uploaded secret: $SECRET_LINES lines"

# AWS Secrets Manager may add a trailing newline, so allow difference of 0-1 lines
LINE_DIFF=$((SECRET_LINES - ENV_LINES))
if [[ "$LINE_DIFF" -eq 0 ]] || [[ "$LINE_DIFF" -eq 1 ]]; then
    log_success "✓ Verification passed!"
    if [[ "$LINE_DIFF" -eq 1 ]]; then
        log_info "Note: AWS Secrets Manager added a trailing newline (this is normal)"
    fi
else
    log_error "Line count mismatch! Difference: $LINE_DIFF lines"
    exit 1
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
log_success "✓ Upload complete!"
echo ""
echo "Secret Details:"
echo "  Name: $SECRET_NAME"
echo "  Region: $AWS_REGION"
echo "  Lines: $SECRET_LINES"
echo ""
echo "Next steps:"
echo "  1. Run: terraform apply"
echo "  2. ECS containers will fetch this secret at startup"
echo ""
echo "To view uploaded secret:"
echo "  aws secretsmanager get-secret-value \\"
echo "    --secret-id $SECRET_NAME \\"
echo "    --region $AWS_REGION \\"
echo "    --query 'SecretString' --output text"
echo ""
