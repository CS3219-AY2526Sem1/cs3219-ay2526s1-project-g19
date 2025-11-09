#!/bin/bash
# =============================================================================
# Docker Entrypoint - Fetch Secrets from AWS Secrets Manager
# =============================================================================
# This script runs before the main container command
# It fetches environment variables from AWS Secrets Manager and exports them
# =============================================================================

set -e

# Configuration from environment or defaults
SECRET_NAME="${AWS_SECRET_NAME:-peerprep/production/env}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ENV_FILE="/app/.env"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# =============================================================================
# Fetch secrets if AWS_SECRET_NAME is set
# =============================================================================

if [ -n "$AWS_SECRET_NAME" ]; then
    log "Fetching secrets from AWS Secrets Manager..."
    log "Secret: $AWS_SECRET_NAME"
    log "Region: $AWS_REGION"

    # Wait for IAM task role to be available (ECS can take a moment)
    MAX_RETRIES=10
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
            log "✓ IAM credentials available"
            break
        fi
        log "Waiting for IAM credentials... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        log "ERROR: Failed to get IAM credentials after $MAX_RETRIES attempts"
        log "Proceeding without secrets (may cause errors if secrets are required)"
    else
        # Fetch secret and write to .env file
        if aws secretsmanager get-secret-value \
            --secret-id "$SECRET_NAME" \
            --region "$AWS_REGION" \
            --query 'SecretString' \
            --output text > "$ENV_FILE" 2>/dev/null; then

            log "✓ Secrets fetched successfully"

            # Export all variables from .env file
            set -a  # Automatically export all variables
            source "$ENV_FILE"
            set +a

            log "✓ Environment variables loaded"
        else
            log "ERROR: Failed to fetch secrets from $SECRET_NAME"
            log "Proceeding without secrets (may cause errors if secrets are required)"
        fi
    fi
else
    log "AWS_SECRET_NAME not set, skipping secrets fetch"
    log "Using environment variables from task definition"
fi

# =============================================================================
# Execute the main container command
# =============================================================================

log "Starting application: $@"
exec "$@"
