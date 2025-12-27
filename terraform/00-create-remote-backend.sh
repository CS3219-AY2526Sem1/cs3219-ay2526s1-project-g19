#!/bin/bash
# =============================================================================
# Bootstrap Terraform Remote Backend (S3 + DynamoDB Lock Table)
# =============================================================================
# Creates the S3 bucket (and optional DynamoDB table) that Terraform uses for
# remote state. Run this once before any terraform init/plan/apply so that
# every developer/CI job can share the same backend.
# =============================================================================

#   export TERRAFORM_STATE_BUCKET=cs3219-g19-terraform-state
#   export TERRAFORM_STATE_REGION=ap-southeast-1
#   export TERRAFORM_STATE_DYNAMODB_TABLE=cs3219-g19-terraform-locks
set -euo pipefail

INFO_COLOR='\033[0;34m'
SUCCESS_COLOR='\033[0;32m'
WARN_COLOR='\033[1;33m'
ERROR_COLOR='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${INFO_COLOR}[INFO]${NC} $1"; }
log_success() { echo -e "${SUCCESS_COLOR}[OK]${NC} $1"; }
log_warn() { echo -e "${WARN_COLOR}[WARN]${NC} $1"; }
log_error() { echo -e "${ERROR_COLOR}[ERR]${NC} $1"; }

usage() {
    cat <<'EOF'
Usage: ./00-create-remote-backend.sh [bucket] [region] [dynamodb_table]

Arguments (all optional, fall back to env vars):
  bucket         Terraform state bucket name (or TERRAFORM_STATE_BUCKET)
  region         AWS region for bucket/table (default: us-east-1)
  dynamodb_table DynamoDB table for state locking (skip when empty)

Environment variables that may be set beforehand:
  TERRAFORM_STATE_BUCKET
  TERRAFORM_STATE_REGION
  TERRAFORM_STATE_DYNAMODB_TABLE

Example:
  export AWS_PROFILE=peerprep-production
  ./00-create-remote-backend.sh peerprep-terraform-state us-east-1 peerprep-terraform-locks

EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

BUCKET=${1:-${TERRAFORM_STATE_BUCKET:-}}
REGION=${2:-${TERRAFORM_STATE_REGION:-us-east-1}}
DDB_TABLE=${3:-${TERRAFORM_STATE_DYNAMODB_TABLE:-}}

if [[ -z "$BUCKET" ]]; then
    log_error "Bucket name is required (pass as arg #1 or set TERRAFORM_STATE_BUCKET)."
    usage
    exit 1
fi

if ! command -v aws &>/dev/null; then
    log_error "aws CLI is required. Install it and ensure credentials are configured (aws configure)."
    exit 1
fi

log_info "Using AWS profile: ${AWS_PROFILE:-<default>}"
log_info "Target bucket: ${BUCKET} (${REGION})"

bucket_exists=false
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    bucket_exists=true
else
    status=$?
    if [[ $status -eq 301 || $status -eq 403 ]]; then
        log_error "Bucket $BUCKET exists in another account or region. Pick a different globally unique name."
        exit 1
    fi
fi

if [[ "$bucket_exists" == true ]]; then
    log_success "Bucket $BUCKET already exists. Skipping creation."
else
    log_info "Creating bucket $BUCKET in $REGION..."
    if [[ "$REGION" == "us-east-1" ]]; then
        aws s3api create-bucket \
            --bucket "$BUCKET" \
            --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    log_success "Bucket created."
fi

if [[ -n "$DDB_TABLE" ]]; then
    log_info "Ensuring DynamoDB table $DDB_TABLE exists in $REGION..."
    if aws dynamodb describe-table --table-name "$DDB_TABLE" --region "$REGION" >/dev/null 2>&1; then
        log_success "DynamoDB table $DDB_TABLE already exists."
    else
        aws dynamodb create-table \
            --table-name "$DDB_TABLE" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$REGION"
        log_success "DynamoDB table created (PAY_PER_REQUEST)."
        log_info "Waiting for DynamoDB table to become ACTIVE..."
        aws dynamodb wait table-exists --table-name "$DDB_TABLE" --region "$REGION"
        log_success "DynamoDB table is ACTIVE."
    fi
else
    log_warn "TERRAFORM_STATE_DYNAMODB_TABLE not set. Skipping lock-table creation (remote state will have no locking)."
fi

cat <<EOF

Next steps:
  export TERRAFORM_STATE_BUCKET=${BUCKET}
  export TERRAFORM_STATE_KEY=peerprep/production/terraform.tfstate
  export TERRAFORM_STATE_REGION=${REGION}
$( [[ -n "$DDB_TABLE" ]] && echo "  export TERRAFORM_STATE_DYNAMODB_TABLE=${DDB_TABLE}" )

Then rerun ./01-terraform-init-plan-create-env.sh.

EOF
