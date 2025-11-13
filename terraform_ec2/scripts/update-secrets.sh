#!/bin/bash
# =============================================================================
# PeerPrep - Update Secrets at Runtime
# =============================================================================
# This script updates secrets on a running EC2 instance.
# Run this after uploading a new secrets/.env to Secrets Manager.
#
# Usage:
#   sudo /opt/peerprep/scripts/update-secrets.sh
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SECRET_NAME="${SECRET_NAME:-peerprep/ec2-prod/env}"
AWS_REGION="${AWS_REGION:-us-east-1}"
APP_DIR="${APP_DIR:-/opt/peerprep}"
ENV_FILE="${APP_DIR}/.env"
FETCH_SCRIPT="${APP_DIR}/scripts/fetch-secrets.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log_info()   { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning(){ echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Root Check
# =============================================================================

if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# =============================================================================
# Validation
# =============================================================================

log_info "PeerPrep Secret Update Script"
echo ""

if [[ ! -f "$FETCH_SCRIPT" ]]; then
    log_error "Fetch script not found: $FETCH_SCRIPT"
    exit 1
fi

if [[ ! -d "$APP_DIR" ]]; then
    log_error "Application directory not found: $APP_DIR"
    exit 1
fi

# =============================================================================
# Fetch Latest Secrets
# =============================================================================

log_info "Fetching latest secrets from AWS Secrets Manager..."
log_info "Secret Name: $SECRET_NAME"
log_info "AWS Region: $AWS_REGION"
echo ""

if bash "$FETCH_SCRIPT" "$SECRET_NAME" "$AWS_REGION" "$ENV_FILE"; then
    log_success "Secrets updated successfully"
else
    log_error "Failed to fetch secrets from AWS Secrets Manager"
    exit 1
fi

echo ""

# =============================================================================
# Restart Docker Compose Services
# =============================================================================

log_info "Restarting docker-compose services to apply new secrets..."
echo ""

cd "$APP_DIR"

# Check if docker-compose is running
if ! docker compose ps --quiet &> /dev/null; then
    log_warning "Docker Compose services not running"
    log_info "Starting services with new secrets..."

    if docker compose up -d; then
        log_success "Services started successfully"
    else
        log_error "Failed to start services"
        exit 1
    fi
else
    log_info "Stopping services..."
    if ! docker compose down; then
        log_error "Failed to stop services"
        exit 1
    fi

    log_info "Starting services with new secrets..."
    if docker compose up -d --build; then
        log_success "Services restarted successfully"
    else
        log_error "Failed to restart services"
        log_info "Attempting to bring services back up..."
        docker compose up -d
        exit 1
    fi
fi

echo ""

# =============================================================================
# Wait for Services to be Healthy
# =============================================================================

log_info "Waiting for services to become healthy..."
sleep 5

# Check container status
RUNNING_CONTAINERS=$(docker compose ps --quiet | wc -l)
TOTAL_CONTAINERS=$(docker compose ps -a --quiet | wc -l)

log_info "Container status: $RUNNING_CONTAINERS/$TOTAL_CONTAINERS running"

if [[ $RUNNING_CONTAINERS -eq $TOTAL_CONTAINERS ]]; then
    log_success "All containers are running"
else
    log_warning "Some containers may not be running. Check with: docker compose ps"
fi

echo ""

# =============================================================================
# Display Service Status
# =============================================================================

log_info "Current service status:"
echo ""
docker compose ps

echo ""

# =============================================================================
# Success
# =============================================================================

log_success "✓ Secret update complete!"
echo ""
echo "Services have been restarted with the latest secrets from AWS Secrets Manager."
echo ""
echo "To verify:"
echo "  docker compose ps              # Check service status"
echo "  docker compose logs -f         # View logs"
echo "  docker compose logs <service>  # View specific service logs"
echo ""

exit 0
