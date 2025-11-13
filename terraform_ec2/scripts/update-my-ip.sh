#!/bin/bash
# =============================================================================
# Update Security Group to Allow Your Current IP for SSH
# =============================================================================
# Usage: ./scripts/update-my-ip.sh
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Get Current IP
# =============================================================================

log_info "Getting your current IP address..."

CURRENT_IP=$(curl -s https://checkip.amazonaws.com)

if [[ -z "$CURRENT_IP" ]]; then
    log_error "Failed to get current IP address"
    exit 1
fi

log_success "Your IP: $CURRENT_IP"

# =============================================================================
# Get Security Group ID from Terraform
# =============================================================================

log_info "Getting security group ID from Terraform..."

cd "$(dirname "$0")/.."

if [[ ! -f terraform.tfstate ]]; then
    log_error "terraform.tfstate not found. Run 'terraform apply' first."
    exit 1
fi

SECURITY_GROUP_ID=$(terraform output -raw security_group_id 2>/dev/null)

if [[ -z "$SECURITY_GROUP_ID" ]]; then
    log_error "Could not get security group ID from Terraform"
    exit 1
fi

log_success "Security Group: $SECURITY_GROUP_ID"

# =============================================================================
# Update Security Group
# =============================================================================

log_info "Adding $CURRENT_IP/32 to security group..."

# Remove old rule if exists (ignore errors)
OLD_IPS=$(aws ec2 describe-security-groups \
    --group-ids "$SECURITY_GROUP_ID" \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`].IpRanges[*].CidrIp' \
    --output text 2>/dev/null || echo "")

if [[ -n "$OLD_IPS" ]]; then
    log_info "Removing old SSH rules..."
    for old_ip in $OLD_IPS; do
        aws ec2 revoke-security-group-ingress \
            --group-id "$SECURITY_GROUP_ID" \
            --protocol tcp \
            --port 22 \
            --cidr "$old_ip" 2>/dev/null || true
        log_info "Removed: $old_ip"
    done
fi

# Add new rule
if aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$CURRENT_IP/32" 2>/dev/null; then
    log_success "✓ SSH access granted for $CURRENT_IP/32"
else
    log_warning "IP may already be authorized (this is fine)"
fi

# =============================================================================
# Get SSH Command
# =============================================================================

INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)
KEY_NAME=$(terraform output -raw key_name 2>/dev/null || echo "")

echo ""
log_success "✓ Setup complete!"
echo ""
echo "You can now SSH into your instance:"
echo ""

if [[ -n "$KEY_NAME" ]]; then
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${INSTANCE_IP}"
else
    echo "  ssh ubuntu@${INSTANCE_IP}"
fi

echo ""
echo "Or use AWS Session Manager (no SSH key needed):"
echo ""
echo "  aws ssm start-session --target \$(terraform output -raw instance_id) --region us-east-1"
echo ""
