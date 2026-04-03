#!/bin/bash
# =============================================================================
# OpenClaw Restat Container
# =============================================================================
# Purpose: Push secrets/openclaw.env to the VPS as the Docker .env file.
# Usage: ./scripts/push-env.sh [VPS_IP]
#
# This script:
#   1. Reads secrets/openclaw.env
#   2. Validates required vars are non-empty
#   3. SCPs it to openclaw@VPS:/home/openclaw/openclaw/.env
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

VPS_USER="openclaw"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
TERRAFORM_DIR="infra/terraform/envs/prod"

# GitHub Container Registry credentials (from local env)
GHCR_USERNAME="${GHCR_USERNAME:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"

if [[ -z "$GHCR_USERNAME" || -z "$GHCR_TOKEN" ]]; then
    echo "[WARN] GHCR_USERNAME and GHCR_TOKEN are not set; private image pulls may fail."
fi

# -----------------------------------------------------------------------------
# Get VPS IP
# -----------------------------------------------------------------------------

if [[ -n "${1:-}" ]]; then
    VPS_IP="$1"
else
    if command -v terraform &> /dev/null && [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
        VPS_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip 2>/dev/null) || {
            echo "Error: Could not get VPS IP from terraform output."
            echo "Usage: $0 <VPS_IP>"
            exit 1
        }
    else
        echo "Error: No VPS IP provided and terraform not available."
        echo "Usage: $0 <VPS_IP>"
        exit 1
    fi
fi


# -----------------------------------------------------------------------------
# Restart existing or pull a latest container 
# -----------------------------------------------------------------------------

echo ""
echo "[...] Restarting container..."

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s "$GHCR_USERNAME" "$GHCR_TOKEN" << 'REMOTE_SCRIPT'
GHCR_USERNAME=$1
GHCR_TOKEN=$2
export GHCR_USERNAME GHCR_TOKEN
echo $GHCR_TOKEN | docker login ghcr.io -u $GHCR_USERNAME --password-stdin 
cd ~/openclaw && docker compose up -d 2>/dev/null
docker logout
REMOTE_SCRIPT

echo ""
echo "=== Done ==="
