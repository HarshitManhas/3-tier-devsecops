#!/usr/bin/env bash
# =============================================================================
# DevOps Project — AWS Secrets Manager Setup
# Run this ONCE before first EKS deployment
# Usage: bash scripts/setup-secrets.sh
# =============================================================================
set -euo pipefail

REGION="ap-south-1"
PROJECT="devops-project-prod"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Validate Prerequisites ─────────────────────────────────────────────────────
command -v aws  >/dev/null 2>&1 || error "AWS CLI not installed"
aws sts get-caller-identity >/dev/null 2>&1 || error "AWS CLI not configured. Run: aws configure"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   DevOps Project — AWS Secrets Manager Setup         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Collect Inputs ─────────────────────────────────────────────────────────────
warn "You will be prompted to enter secret values. They will NOT be displayed."
echo ""

read -rp "  RDS Endpoint (from terraform output): " RDS_HOST
read -rp "  RDS DB name  [crud_app]:              " RDS_DBNAME
RDS_DBNAME="${RDS_DBNAME:-crud_app}"
read -rp "  RDS username [appuser]:               " RDS_USER
RDS_USER="${RDS_USER:-appuser}"
read -rsp " RDS password:                          " RDS_PASS; echo ""
read -rsp " JWT Secret (min 32 chars, random):     " JWT_SECRET; echo ""
read -rp "  Admin email  [admin@example.com]:      " ADMIN_EMAIL
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
read -rsp " Admin password (min 8 chars):          " ADMIN_PASS; echo ""

echo ""

# ── Validate Inputs ─────────────────────────────────────────────────────────────
[[ -z "$RDS_HOST"    ]] && error "RDS_HOST cannot be empty"
[[ -z "$RDS_PASS"    ]] && error "RDS password cannot be empty"
[[ ${#JWT_SECRET} -lt 32 ]] && error "JWT_SECRET must be at least 32 characters"
[[ ${#ADMIN_PASS} -lt 8  ]] && error "Admin password must be at least 8 characters"

# ── Helper: create or update a secret ──────────────────────────────────────────
create_or_update_secret() {
  local NAME="$1"
  local VALUE="$2"
  local DESC="$3"

  if aws secretsmanager describe-secret \
        --secret-id "$NAME" \
        --region "$REGION" >/dev/null 2>&1; then
    info "Updating existing secret: $NAME"
    aws secretsmanager put-secret-value \
      --secret-id "$NAME" \
      --secret-string "$VALUE" \
      --region "$REGION" >/dev/null
  else
    info "Creating secret: $NAME"
    aws secretsmanager create-secret \
      --name "$NAME" \
      --description "$DESC" \
      --secret-string "$VALUE" \
      --region "$REGION" >/dev/null
  fi
}

# ── 1. RDS Credentials ─────────────────────────────────────────────────────────
info "Creating RDS credentials secret..."
create_or_update_secret \
  "${PROJECT}/rds/credentials" \
  "{\"host\":\"${RDS_HOST}\",\"port\":\"3306\",\"dbname\":\"${RDS_DBNAME}\",\"username\":\"${RDS_USER}\",\"password\":\"${RDS_PASS}\"}" \
  "RDS MySQL credentials for DevOps Project"

# ── 2. App Secrets ─────────────────────────────────────────────────────────────
info "Creating app secrets (JWT + Admin)..."
create_or_update_secret \
  "${PROJECT}/app/secrets" \
  "{\"jwt_secret\":\"${JWT_SECRET}\",\"admin_email\":\"${ADMIN_EMAIL}\",\"admin_password\":\"${ADMIN_PASS}\"}" \
  "Application secrets for DevOps Project"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   ✅  Secrets created successfully!                   ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║   ${PROJECT}/rds/credentials                         ║"
echo "║   ${PROJECT}/app/secrets                             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
info "Next step: Apply K8s manifests"
echo "  kubectl apply -f gitops/infra/externalsecrets.yaml"
echo "  kubectl apply -f gitops/apps/namespace.yaml"
echo "  kubectl apply -f gitops/apps/frontend/"
echo "  kubectl apply -f gitops/apps/backend/"
echo ""
