#!/bin/bash
# =============================================================================
# PeerPrep EC2 User Data - Instance Initialization Script
# =============================================================================
# This script runs once when the EC2 instance is first created
# It sets up Docker, clones the repo, fetches secrets from AWS, and starts services
# =============================================================================

set -euxo pipefail

# =============================================================================
# Template Variables (Passed from Terraform)
# =============================================================================
REPO_URL="${github_repo_url}"
BRANCH="${github_branch}"
USE_SECRETS_MANAGER="${use_secrets_manager}"
SECRETS_MANAGER_NAME="${secrets_manager_name}"
AWS_REGION="${aws_region}"
APP_DIR="/opt/peerprep"

# =============================================================================
# Logging
# =============================================================================
exec > >(tee /var/log/user-data.log)
exec 2>&1

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting PeerPrep EC2 initialization..."

# =============================================================================
# System Setup
# =============================================================================

log "Updating system and installing essentials..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl wget git jq ca-certificates gnupg lsb-release unzip

# Install AWS CLI v2 (if not already installed)
if ! command -v aws &> /dev/null; then
    log "Installing AWS CLI v2..."
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

log "AWS CLI version: $(aws --version)"

# =============================================================================
# Install Docker
# =============================================================================

log "Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

log "Docker installed: $(docker --version)"
log "Docker Compose installed: $(docker compose version)"

# =============================================================================
# Clone Repository
# =============================================================================

log "Cloning repository from $REPO_URL (branch: $BRANCH)..."
mkdir -p "$APP_DIR"
cd "$APP_DIR"

if [[ -d .git ]]; then
    log "Repository already exists, pulling latest changes..."
    git fetch origin
    git checkout "$BRANCH"
    git pull
else
    log "Cloning repository..."
    git clone -b "$BRANCH" "$REPO_URL" .
fi

log "Repository cloned successfully"

# =============================================================================
# Copy Scripts to Application Directory
# =============================================================================

log "Setting up secret management scripts..."

# Ensure scripts directory exists
mkdir -p "$APP_DIR/scripts"

# Copy fetch-secrets script from repo (already in terraform_ec2/scripts/)
if [[ -f "$APP_DIR/terraform_ec2/scripts/fetch-secrets.sh" ]]; then
    cp "$APP_DIR/terraform_ec2/scripts/fetch-secrets.sh" "$APP_DIR/scripts/"
    chmod +x "$APP_DIR/scripts/fetch-secrets.sh"
    log "Copied fetch-secrets.sh"
fi

# Copy update-secrets script from repo
if [[ -f "$APP_DIR/terraform_ec2/scripts/update-secrets.sh" ]]; then
    cp "$APP_DIR/terraform_ec2/scripts/update-secrets.sh" "$APP_DIR/scripts/"
    chmod +x "$APP_DIR/scripts/update-secrets.sh"
    log "Copied update-secrets.sh"
fi

# =============================================================================
# Fetch Secrets and Create .env
# =============================================================================

if [[ "$USE_SECRETS_MANAGER" == "true" ]]; then
    log "Fetching secrets from AWS Secrets Manager..."
    log "Secret Name: $SECRETS_MANAGER_NAME"
    log "AWS Region: $AWS_REGION"

    # Run fetch-secrets script
    if bash "$APP_DIR/scripts/fetch-secrets.sh" "$SECRETS_MANAGER_NAME" "$AWS_REGION" "$APP_DIR/.env"; then
        log "✓ Secrets fetched from AWS Secrets Manager successfully"
    else
        log "ERROR: Failed to fetch secrets from AWS Secrets Manager"
        log "Check: Did you run terraform_ec2/scripts/setup-ssm-secrets.sh?"
        exit 1
    fi
else
    log "Remote secrets disabled, using root .env file from repo..."

    # Copy .env from repo root (for development/testing)
    if [[ -f "$APP_DIR/.env" ]]; then
        log "✓ Using existing .env from repository"
    else
        log "ERROR: No .env file found in repository root"
        log "Either:"
        log "  1. Enable remote secrets: set use_secrets_manager = true in terraform.tfvars"
        log "  2. Or commit a .env file to your repo (not recommended)"
        exit 1
    fi
fi

# Verify .env exists
if [[ ! -f "$APP_DIR/.env" ]]; then
    log "ERROR: No .env file found!"
    log "This should never happen. Check the logic above."
    exit 1
fi

# Set proper permissions
chmod 600 "$APP_DIR/.env"
chown ubuntu:ubuntu "$APP_DIR/.env"
log "✓ .env file secured (chmod 600)"

# =============================================================================
# Start Docker Compose Services
# =============================================================================

log "Starting Docker Compose services..."
cd "$APP_DIR"

# Pull images first (faster subsequent starts)
docker compose pull || log "WARNING: Failed to pull some images, will build instead"

# Start all services
if docker compose up -d --build; then
    log "✓ Docker Compose services started successfully"
else
    log "ERROR: Failed to start Docker Compose services"
    log "Check logs with: docker compose logs"
fi

# Wait for services to initialize
sleep 10

# Show service status
log "Service status:"
docker compose ps

# =============================================================================
# Create Systemd Service
# =============================================================================

log "Creating systemd service for automatic startup..."

cat > /etc/systemd/system/peerprep.service <<'UNIT'
[Unit]
Description=PeerPrep Docker Compose Application
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/peerprep
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
User=ubuntu
Group=ubuntu
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable peerprep.service

log "✓ Systemd service created and enabled"

# =============================================================================
# Final Status
# =============================================================================

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

log "=============================================="
log "✓ PeerPrep EC2 initialization complete!"
log "=============================================="
log ""
log "Access your application at:"
log "  http://$PUBLIC_IP"
log ""
log "Useful commands:"
log "  docker compose ps              # View service status"
log "  docker compose logs -f         # View logs"
log "  sudo systemctl status peerprep # Check systemd service"
log ""

if [[ "$USE_SSM_SECRETS" == "true" ]]; then
    log "Secret management:"
    log "  sudo /opt/peerprep/scripts/update-secrets.sh  # Refresh secrets from SSM"
    log ""
fi

log "Setup complete at $(date)"
log "=============================================="
