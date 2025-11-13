#!/bin/bash
# =============================================================================
# Upload secrets/.env to AWS Secrets Manager
# =============================================================================
# Usage: ./scripts/setup-ssm-secrets.sh [secrets_dir]
# =============================================================================

set -euo pipefail

# Configuration
SECRETS_DIR="${1:-../secrets}"
ENV_FILE="${SECRETS_DIR}/.env"
AWS_REGION="${AWS_REGION:-us-east-1}"
SECRET_NAME="${SECRET_NAME:-peerprep/ec2-prod/env}"
SECRET_DESCRIPTION="${SECRET_DESCRIPTION:-PeerPrep EC2 environment variables}"
APPLY_TAGS="${APPLY_TAGS:-true}"
TAG_ARGS=(Key=Project,Value=peerprep Key=Environment,Value=ec2-prod)

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

log_info "Uploading secrets to AWS Secrets Manager..."

if [[ ! -f "$ENV_FILE" ]]; then
    log_error "File not found: $ENV_FILE"
    echo ""
    echo "Create the file first:"
    echo "  mkdir -p secrets"
    echo "  cp terraform_ec2/.env.secrets.template secrets/.env"
    echo "  # Edit secrets/.env with your values"
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
log_info "Secrets Manager Name: $SECRET_NAME"
echo ""

# =============================================================================
# Upload .env file
# =============================================================================

log_info "Uploading complete .env file to Secrets Manager..."
file_size=$(wc -c < "$ENV_FILE")
if [[ $file_size -gt 65536 ]]; then
    log_error "Secret size exceeds the 64KB Secrets Manager limit (current: ${file_size} bytes)"
    exit 1
fi

if aws secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    &> /dev/null; then
    log_info "Secret exists, updating..."
    if ! output=$(aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "file://$ENV_FILE" \
        --region "$AWS_REGION" 2>&1); then
        log_error "Failed to update secret"
        echo "$output"
        exit 1
    fi
else
    log_info "Secret not found, creating..."
    if ! output=$(aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "$SECRET_DESCRIPTION" \
        --secret-string "file://$ENV_FILE" \
        --region "$AWS_REGION" \
        --tags "${TAG_ARGS[@]}" 2>&1); then
        log_error "Failed to create secret"
        echo "$output"
        exit 1
    fi
fi

if [[ "$APPLY_TAGS" == "true" ]]; then
    log_info "Ensuring tags are applied..."
    if ! tag_output=$(aws secretsmanager tag-resource \
        --secret-id "$SECRET_NAME" \
        --tags "${TAG_ARGS[@]}" \
        --region "$AWS_REGION" 2>&1); then
        log_error "Failed to tag secret"
        echo "$tag_output"
    else
        log_success "✓ Tags applied"
    fi
fi

log_success "✓ Uploaded to Secrets Manager: $SECRET_NAME"

echo ""
log_success "✓ Upload complete!"
echo ""
echo "Next steps:"
echo "  1. In terraform.tfvars set:"
echo "     use_secrets_manager  = true"
echo "     secrets_manager_name = \"$SECRET_NAME\""
echo ""
echo "  2. Deploy:"
echo "     cd terraform_ec2"
echo "     terraform apply"
echo ""
echo "To view uploaded secrets:"
echo "  aws secretsmanager get-secret-value --secret-id $SECRET_NAME --region $AWS_REGION --query 'SecretString' --output text"
echo ""
