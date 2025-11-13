#!/bin/bash
# =============================================================================
# Fetch .env from AWS Secrets Manager
# =============================================================================
# This script runs on EC2 to download the entire .env file from AWS
# Usage: ./fetch-secrets.sh [secret_name] [aws_region] [output_file]
# =============================================================================

set -euo pipefail

# Configuration
SECRET_NAME="${1:-peerprep/ec2-prod/env}"
AWS_REGION="${2:-us-east-1}"
OUTPUT_FILE="${3:-/opt/peerprep/.env}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/peerprep-secrets.log
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a /var/log/peerprep-secrets.log >&2
}

# =============================================================================
# Validation
# =============================================================================

log "Fetching .env from AWS Secrets Manager..."
log "Secret Name: ${SECRET_NAME}"
log "Region: $AWS_REGION"
log "Output: $OUTPUT_FILE"

# Wait for IAM instance profile
log "Waiting for IAM instance profile..."
MAX_RETRIES=30
RETRY_COUNT=0

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
        log "IAM instance profile ready"
        break
    fi
    log "Waiting for IAM credentials... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    sleep 2
    ((RETRY_COUNT++))
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
    log_error "Failed to get IAM credentials after $MAX_RETRIES attempts"
    exit 1
fi

# =============================================================================
# Fetch .env from Secrets Manager
# =============================================================================

log "Downloading .env file from Secrets Manager..."

ENV_CONTENT=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text 2>&1)

if [[ $? -ne 0 ]]; then
    log_error "Failed to fetch .env from Secrets Manager"
    log_error "$ENV_CONTENT"
    log_error "Make sure you ran: ./scripts/setup-ssm-secrets.sh"
    exit 1
fi

# =============================================================================
# Write .env file
# =============================================================================

log "Writing .env file to $OUTPUT_FILE"

# Backup existing .env if it exists
if [[ -f "$OUTPUT_FILE" ]]; then
    BACKUP_FILE="${OUTPUT_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backing up existing .env to $BACKUP_FILE"
    cp "$OUTPUT_FILE" "$BACKUP_FILE"
fi

# Write new .env file
echo "$ENV_CONTENT" > "$OUTPUT_FILE"

# Set permissions
chmod 600 "$OUTPUT_FILE"
chown ubuntu:ubuntu "$OUTPUT_FILE" 2>/dev/null || true

# =============================================================================
# Verification
# =============================================================================

log "Verifying .env file..."

TOTAL_LINES=$(wc -l < "$OUTPUT_FILE" | xargs)
log "Created .env with $TOTAL_LINES lines"

# Check for critical variables
CRITICAL_VARS=("SECRET_KEY" "QUESTION_DB_PASSWORD")
MISSING_VARS=()

for var in "${CRITICAL_VARS[@]}"; do
    if ! grep -q "^${var}=" "$OUTPUT_FILE"; then
        MISSING_VARS+=("$var")
    fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
    log_error "Missing critical variables: ${MISSING_VARS[*]}"
    exit 1
fi

log "✓ .env file created successfully from Secrets Manager"
log "✓ All critical variables present"

exit 0
