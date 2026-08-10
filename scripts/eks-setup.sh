#!/usr/bin/env bash
# =============================================================================
# DevOps Project — EKS Post-Deploy Setup
# Run this ONCE on the Jenkins EC2 after terraform apply
# Usage: bash scripts/eks-setup.sh
# =============================================================================
set -euo pipefail

REGION="ap-south-1"
CLUSTER_NAME="devops-project-prod-eks"
NAMESPACE="devops-project"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
step()  { echo -e "\n${GREEN}══ $* ${NC}"; }

# ── Prerequisites ─────────────────────────────────────────────────────────────
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
command -v helm    >/dev/null 2>&1 || { echo "helm not found";    exit 1; }
command -v aws     >/dev/null 2>&1 || { echo "aws cli not found"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   DevOps Project — EKS Full Setup Script             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ══ Step 1: Connect kubectl to EKS ───────────────────────────────────────────
step "1/7  Connect kubectl to EKS"
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER_NAME"
kubectl get nodes
info "kubectl connected ✅"

# ══ Step 2: Create Application Namespace ──────────────────────────────────────
step "2/7  Create namespace: $NAMESPACE"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    app: devops-project
EOF
info "Namespace created ✅"

# ══ Step 3: Install AWS Load Balancer Controller ───────────────────────────────
step "3/7  Install AWS Load Balancer Controller"
helm repo add eks https://aws.github.io/eks-charts
helm repo update
# Create IAM service account (requires eksctl or manual IAM setup)
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set region="$REGION"
info "ALB Controller installed ✅"

# ══ Step 4: Install External Secrets Operator ─────────────────────────────────
step "4/7  Install External Secrets Operator (reads from AWS Secrets Manager)"
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --wait
info "External Secrets Operator installed ✅"

# ══ Step 5: Install Argo CD ───────────────────────────────────────────────────
step "5/7  Install Argo CD"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --wait \
  --set server.service.type=LoadBalancer

# Get Argo CD password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

info "Argo CD installed ✅"
echo ""
warn "══════════════════════════════════════════════"
warn "  Argo CD admin password: ${ARGOCD_PASSWORD}"
warn "  Save this password now!"
warn "══════════════════════════════════════════════"
echo ""

# ══ Step 6: Install Monitoring Stack (Prometheus + Grafana) ───────────────────
step "6/7  Install Prometheus + Grafana"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --set grafana.adminPassword="DevOps@Grafana123" \
  --set prometheus.prometheusSpec.retention=7d

info "Monitoring stack installed ✅"

# ══ Step 7: Apply ExternalSecrets (after secrets are in Secrets Manager) ──────
step "7/7  Apply ExternalSecrets manifests"
warn "Make sure you ran scripts/setup-secrets.sh first!"
read -rp "  Did you run setup-secrets.sh? (y/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  kubectl apply -f gitops/infra/externalsecrets.yaml
  kubectl apply -f gitops/infra/rbac.yaml
  info "ExternalSecrets applied ✅"
else
  warn "Skipped. Run later: kubectl apply -f gitops/infra/externalsecrets.yaml"
fi

# ══ Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   ✅  EKS Setup Complete!                                     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Next: Apply Argo CD app-of-apps:                            ║"
echo "║   1. Edit gitops/argocd/app-of-apps.yaml (set your repo URL) ║"
echo "║   2. kubectl apply -f gitops/argocd/app-of-apps.yaml          ║"
echo "║   3. Argo CD will auto-deploy frontend + backend pods         ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Port-forward Argo CD UI:                                     ║"
echo "║   kubectl port-forward svc/argocd-server -n argocd 8081:443   ║"
echo "║   Open: http://localhost:8081  Login: admin / <above password> ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Port-forward Grafana:                                        ║"
echo "║   kubectl port-forward svc/monitoring-grafana -n monitoring \  ║"
echo "║              3000:80                                           ║"
echo "║   Open: http://localhost:3000  Login: admin / DevOps@Grafana123║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
