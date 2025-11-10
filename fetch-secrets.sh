#!/bin/bash
# Fetch secrets from AWS Secrets Manager and export as environment variables
# This should be sourced at the beginning of docker-entrypoint.sh

if [ -n "$AWS_SECRET_NAME" ] && [ -n "$AWS_REGION" ]; then
    echo "[Secret Fetch] Fetching secrets from $AWS_SECRET_NAME in $AWS_REGION..."
    
    # Fetch secret and export all variables
    SECRET_STRING=$(aws secretsmanager get-secret-value \
        --secret-id "$AWS_SECRET_NAME" \
        --region "$AWS_REGION" \
        --query 'SecretString' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$SECRET_STRING" ]; then
        # Export all variables from the secret
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            if [ -z "$key" ] || [[ "$key" =~ ^# ]]; then
                continue
            fi
            # Remove quotes from value if present
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            export "$key=$value"
        done <<< "$SECRET_STRING"
        
        echo "[Secret Fetch] ✓ Secrets loaded successfully"
    else
        echo "[Secret Fetch] ⚠ Failed to fetch secrets, using existing environment variables"
    fi
else
    echo "[Secret Fetch] ⚠ AWS_SECRET_NAME or AWS_REGION not set, skipping secret fetch"
fi
