#!/bin/bash
# =============================================================================
# Terraform Init + Plan + Env Sync
# =============================================================================
# - Runs terraform init/plan (remote backend)
# - Captures outputs to terraform-outputs.json
# - Updates .env.prod-ecs placeholders with live endpoints
# - Uploads the env file to AWS Secrets Manager
# =============================================================================

set -euo pipefail

AWS_REGION=${AWS_REGION:-ap-southeast-1}
PROJECT_NAME=${PROJECT_NAME:-peerprep}
SECRET_ENVIRONMENT=${SECRET_ENVIRONMENT:-prod}
ENV_FILE="${1:-../.env.prod-ecs}"
UPLOAD_SECRETS=${UPLOAD_SECRETS:-true}
AUTO_APPROVE=${AUTO_APPROVE:-false}
BACKEND_BUCKET=${TERRAFORM_STATE_BUCKET:-}
BACKEND_KEY=${TERRAFORM_STATE_KEY:-peerprep/production/terraform.tfstate}
BACKEND_REGION=${TERRAFORM_STATE_REGION:-us-east-1}
BACKEND_DYNAMODB_TABLE=${TERRAFORM_STATE_DYNAMODB_TABLE:-}
BACKEND_PROFILE=${TERRAFORM_STATE_PROFILE:-}

cd "$(dirname "$0")"

INFO_COLOR='\033[0;34m'
SUCCESS_COLOR='\033[0;32m'
WARN_COLOR='\033[1;33m'
ERROR_COLOR='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${INFO_COLOR}[INFO]${NC} $1"; }
log_success() { echo -e "${SUCCESS_COLOR}[OK]${NC} $1"; }
log_warn() { echo -e "${WARN_COLOR}[WARN]${NC} $1"; }
log_error() { echo -e "${ERROR_COLOR}[ERR]${NC} $1"; }
to_lower() { printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
ensure_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        return
    fi

    local template="../.env.prod-ecs.template"
    if [[ -f "$template" ]]; then
        log_warn "$ENV_FILE not found. Creating from template..."
        cp "$template" "$ENV_FILE"
    else
        log_error "Neither $ENV_FILE nor $template exists."
        exit 1
    fi
}

replace_placeholder() {
    local placeholder=$1
    local value=$2

    if [[ -z "$value" || "$value" == "null" ]]; then
        log_warn "Skipping $placeholder (no value available)"
        missing_placeholders+=("$placeholder")
        return
    fi

    if ! grep -q "$placeholder" "$ENV_FILE"; then
        log_warn "Placeholder $placeholder not found in $ENV_FILE"
        return
    fi

    python3 - "$ENV_FILE" "$placeholder" "$value" <<'PY'
import sys
path, needle, replacement = sys.argv[1:4]
with open(path, "r", encoding="utf-8") as fh:
    data = fh.read()

if needle not in data:
    sys.exit(0)

with open(path, "w", encoding="utf-8") as fh:
    fh.write(data.replace(needle, replacement))
PY

    log_success "Updated $placeholder -> $value"
}

get_output() {
    local key=$1
    jq -r --arg key "$key" '.[$key].value // empty' terraform-outputs.json
}

terraform_init() {
    local init_args=(-upgrade)

    if [[ -n "$BACKEND_BUCKET" ]]; then
        log_info "Using remote backend: s3://${BACKEND_BUCKET}/${BACKEND_KEY}"
        init_args+=(-reconfigure)
        init_args+=(-backend-config="bucket=${BACKEND_BUCKET}")
        init_args+=(-backend-config="key=${BACKEND_KEY}")
        init_args+=(-backend-config="region=${BACKEND_REGION}")

        if [[ -n "$BACKEND_DYNAMODB_TABLE" ]]; then
            init_args+=(-backend-config="dynamodb_table=${BACKEND_DYNAMODB_TABLE}")
        fi

        if [[ -n "$BACKEND_PROFILE" ]]; then
            init_args+=(-backend-config="profile=${BACKEND_PROFILE}")
        fi
    else
        log_warn "TERRAFORM_STATE_BUCKET not set; defaulting to local state (terraform.tfstate)"
    fi

    terraform init "${init_args[@]}"
}

# -----------------------------------------------------------------------------
# Pre-flight Checks & Auto-fixes
# -----------------------------------------------------------------------------
check_and_unlock_state() {
    log_info "Checking for stale state locks..."

    # Try to get lock info (will fail if no lock exists)
    local lock_output=$(terraform plan -lock=false -detailed-exitcode 2>&1 || true)

    # Check if there's a lock error
    if echo "$lock_output" | grep -q "Error acquiring the state lock"; then
        local lock_id=$(echo "$lock_output" | grep -oP 'ID:\s+\K[a-f0-9-]+' | head -1)

        if [[ -n "$lock_id" ]]; then
            log_warn "Found stale state lock (ID: $lock_id)"
            log_warn "This usually happens when a previous operation was interrupted"

            if [[ "$(to_lower "$AUTO_APPROVE")" == "true" ]]; then
                log_info "AUTO_APPROVE=true, unlocking automatically..."
                echo "yes" | terraform force-unlock "$lock_id" >/dev/null 2>&1
                log_success "State unlocked"
            else
                read -p "Force unlock state? (yes/no): " UNLOCK_CONFIRM
                if [[ "$UNLOCK_CONFIRM" == "yes" ]]; then
                    echo "yes" | terraform force-unlock "$lock_id" >/dev/null 2>&1
                    log_success "State unlocked"
                else
                    log_error "Cannot proceed with locked state"
                    exit 1
                fi
            fi
        fi
    else
        log_success "No stale locks found"
    fi
}

check_and_fix_secrets() {
    local secret_name="${PROJECT_NAME}/${SECRET_ENVIRONMENT}/env"

    log_info "Checking Secrets Manager state..."

    # Check if secret exists and capture the full output
    local describe_output
    describe_output=$(aws secretsmanager describe-secret \
        --secret-id "$secret_name" \
        --region "$AWS_REGION" 2>&1 || true)

    # Check if secret is scheduled for deletion using JSON query
    if echo "$describe_output" | grep -q "DeletedDate"; then
        log_warn "Secret is scheduled for deletion. Force deleting to recreate..."
        aws secretsmanager delete-secret \
            --secret-id "$secret_name" \
            --region "$AWS_REGION" \
            --force-delete-without-recovery >/dev/null 2>&1 || true

        sleep 3
        log_success "Secret force deleted. Will be recreated by Terraform."

    # Check if secret exists (and is not scheduled for deletion)
    elif echo "$describe_output" | grep -q "ARN"; then
        if ! terraform state show aws_secretsmanager_secret.ecs_env >/dev/null 2>&1; then
            log_warn "Secret exists but not in Terraform state. Importing..."
            if terraform import aws_secretsmanager_secret.ecs_env "$secret_name" 2>&1; then
                # Import version too
                local version_id=$(aws secretsmanager get-secret-value \
                    --secret-id "$secret_name" \
                    --region "$AWS_REGION" \
                    --query 'VersionId' \
                    --output text 2>/dev/null || echo "")

                local secret_arn=$(aws secretsmanager describe-secret \
                    --secret-id "$secret_name" \
                    --region "$AWS_REGION" \
                    --query 'ARN' \
                    --output text 2>/dev/null || echo "")

                if [[ -n "$version_id" && -n "$secret_arn" ]]; then
                    terraform import aws_secretsmanager_secret_version.ecs_env "${secret_arn}|${version_id}" 2>&1 || true
                fi

                log_success "Secret imported into Terraform state"
            else
                log_warn "Import failed, but continuing (Terraform will create the secret)"
            fi
        fi
    else
        log_info "Secret does not exist. Terraform will create it."
    fi
}

check_terraform_vars() {
    log_info "Checking terraform.tfvars..."

    if [[ ! -f "terraform.tfvars" ]] || [[ ! -s "terraform.tfvars" ]]; then
        log_warn "terraform.tfvars is missing or empty!"
        log_warn "Creating terraform.tfvars with default password..."
        log_warn "IMPORTANT: Change the db_password before production use!"

        cat > terraform.tfvars <<'EOF'
# =============================================================================
# Terraform Variables - Production
# =============================================================================
# IMPORTANT: Change these values before production deployment!

# Database password - CHANGE THIS!
# Requirements: 8+ characters, no /, ", @, or spaces
db_password = "PeerPrep2024!Secure#Pass"
EOF
        log_success "Created terraform.tfvars with default values"
        log_error "Please review and update terraform.tfvars with secure credentials!"
        read -p "Press Enter to continue after reviewing terraform.tfvars..."
    fi
}

# -----------------------------------------------------------------------------
# 1. Pre-flight checks & auto-fixes
# -----------------------------------------------------------------------------
check_terraform_vars

# -----------------------------------------------------------------------------
# 2. Terraform init & plan
# -----------------------------------------------------------------------------
log_info "Running terraform init..."
terraform_init
log_success "Terraform init complete"

# Check and fix secrets BEFORE checking locks (to prevent import errors)
check_and_fix_secrets

# Check for stale locks and unlock if needed
check_and_unlock_state

log_info "Running terraform plan..."
terraform plan -out=tfplan
log_success "Plan saved to tfplan (review with: terraform show tfplan)"

CONFIRM=""
if [[ "$(to_lower "$AUTO_APPROVE")" == "true" ]]; then
    CONFIRM="yes"
else
    read -p "Apply this plan now? (yes/no): " CONFIRM
fi

if [[ "$CONFIRM" != "yes" ]]; then
    log_warn "Apply skipped by user. Terraform outputs/env sync require the plan to be applied."
    log_warn "Run 'terraform apply tfplan' (or re-run with AUTO_APPROVE=true) before rerunning this script."
    exit 0
fi

log_info "Applying terraform plan..."
terraform apply tfplan
log_success "Terraform apply complete"

log_info "Capturing terraform outputs..."
terraform output -json > terraform-outputs.json
log_success "Outputs saved to terraform-outputs.json"

# -----------------------------------------------------------------------------
# 3. Sync outputs into .env.prod-ecs
# -----------------------------------------------------------------------------
ensure_env_file

missing_placeholders=()

log_info "Updating placeholders in $ENV_FILE..."
NAMESPACE=$(get_output "service_discovery_namespace_name")
ALB_DNS=$(get_output "alb_dns_name")
USER_DB=$(get_output "rds_user_endpoint")
QUESTION_DB=$(get_output "rds_question_endpoint")
MATCHING_DB=$(get_output "rds_matching_endpoint")
SESSION_DB=$(get_output "rds_session_endpoint")
MATCHING_REDIS=$(get_output "redis_matching_endpoint")
COLLAB_REDIS=$(get_output "redis_collaboration_endpoint")
CHAT_REDIS=$(get_output "redis_chat_endpoint")

replace_placeholder "CHANGEME_NAMESPACE" "$NAMESPACE"
replace_placeholder "CHANGEME_ALB_DNS_NAME" "$ALB_DNS"
replace_placeholder "CHANGEME_RDS_USER_ENDPOINT" "$USER_DB"
replace_placeholder "CHANGEME_RDS_QUESTION_ENDPOINT" "$QUESTION_DB"
replace_placeholder "CHANGEME_RDS_MATCHING_ENDPOINT" "$MATCHING_DB"
replace_placeholder "CHANGEME_RDS_SESSION_ENDPOINT" "$SESSION_DB"
replace_placeholder "CHANGEME_ELASTICACHE_MATCHING_ENDPOINT" "$MATCHING_REDIS"
replace_placeholder "CHANGEME_ELASTICACHE_COLLABORATION_ENDPOINT" "$COLLAB_REDIS"
replace_placeholder "CHANGEME_ELASTICACHE_CHAT_ENDPOINT" "$CHAT_REDIS"

# Generic Redis placeholder (best-effort: use matching endpoint)
if [[ -n "$MATCHING_REDIS" ]]; then
    replace_placeholder "CHANGEME_ELASTICACHE_ENDPOINT" "$MATCHING_REDIS"
fi

if (( ${#missing_placeholders[@]} > 0 )); then
    log_error "Missing terraform outputs for: ${missing_placeholders[*]}"
    log_error "Ensure remote state is accessible (terraform output must return values) and rerun this script."
    exit 1
fi

log_success "Placeholder sync complete"

# -----------------------------------------------------------------------------
# 4. Upload to AWS Secrets Manager
# -----------------------------------------------------------------------------
if [[ "${UPLOAD_SECRETS}" == "false" || "${UPLOAD_SECRETS}" == "FALSE" ]]; then
    log_warn "UPLOAD_SECRETS=false, skipping Secrets Manager upload"
else
    log_info "Uploading $ENV_FILE to AWS Secrets Manager..."
    ./scripts/upload-secrets-to-aws.sh "$ENV_FILE" "$SECRET_ENVIRONMENT" "$AWS_REGION"
    log_success "Secrets uploaded to ${PROJECT_NAME}/${SECRET_ENVIRONMENT}/env"
fi

echo ""
log_success "All done!"
echo "Next:"
echo "  1. Review plan: terraform show tfplan | less"
echo "  2. Build/push images: ./03-build-and-push-images.sh"
