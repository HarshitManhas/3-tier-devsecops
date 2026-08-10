# 📦 DevSecOps GitOps — Kubernetes Manifests

<div align="center">

**Kubernetes manifests for the DevSecOps 3-Tier Application**
**Auto-synced to AWS EKS by Argo CD**

[![Argo CD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)]()
[![Kubernetes](https://img.shields.io/badge/Platform-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)]()
[![AWS EKS](https://img.shields.io/badge/Cloud-AWS%20EKS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)]()

</div>

---

## 🔗 Related Repository

| Repo | Description |
|------|-------------|
| **[3-tier-devsecops](https://github.com/YOUR_USERNAME/3-tier-devsecops)** | App code, Jenkins CI pipeline, Terraform, Ansible |
| **[3-tier-devsecops-gitops](https://github.com/YOUR_USERNAME/3-tier-devsecops-gitops)** ← You are here | Kubernetes manifests (watched by Argo CD) |

---

## 🔄 How This Repo Works

```
Jenkins CI Pipeline (in App Repo)
  │
  │  Stage 9: git push — bumps image tag
  ▼
This GitOps Repo (auto-updated by Jenkins)
  │
  │  Argo CD polls every 3 minutes
  ▼
Argo CD detects change
  │
  │  Rolling update
  ▼
AWS EKS Cluster — Zero downtime deployment ✅
```

> ⚠️ **Do NOT edit deployment image tags manually.**
> They are automatically updated by Jenkins on every successful build.

---

## 📁 Structure

```
3-tier-devsecops-gitops/
│
├── 📁 apps/
│   ├── namespace.yaml               # devops-project namespace
│   ├── frontend/
│   │   ├── deployment.yaml          # React + nginx (2 replicas, rolling update)
│   │   ├── service.yaml             # ClusterIP → ALB
│   │   ├── configmap.yaml           # REACT_APP_API_URL
│   │   ├── hpa.yaml                 # Auto-scale 2–8 pods on CPU
│   │   └── networkpolicy.yaml       # Only ALB ingress allowed
│   └── backend/
│       ├── deployment.yaml          # Node.js (2 replicas, rolling update)
│       ├── service.yaml             # ClusterIP
│       ├── configmap.yaml           # ALLOWED_ORIGINS
│       ├── hpa.yaml                 # Auto-scale 2–8 pods on CPU/memory
│       └── networkpolicy.yaml       # Only frontend + monitoring allowed
│
├── 📁 infra/
│   ├── ingress.yaml                 # AWS ALB + ACM TLS (HTTPS :443)
│   ├── rbac.yaml                    # ServiceAccounts + minimal RBAC
│   ├── externalsecrets.yaml         # Pull from AWS Secrets Manager
│   └── monitoring/
│       ├── prometheus-values.yaml   # Prometheus Helm values
│       └── loki-values.yaml         # Loki Helm values
│
└── 📁 argocd/
    ├── app-of-apps.yaml             # Root Argo CD application
    └── apps/
        ├── frontend-app.yaml        # Argo CD app for frontend
        └── backend-app.yaml        # Argo CD app for backend
```

---

## 🚀 Deploy with Argo CD

### 1. Edit repo URL (one time)
In `argocd/app-of-apps.yaml`, replace:
```yaml
repoURL: https://github.com/YOUR_USERNAME/3-tier-devsecops-gitops
```

### 2. Apply
```bash
kubectl apply -f argocd/app-of-apps.yaml
```

Argo CD will automatically deploy all apps and keep them in sync.

### 3. Verify
```bash
kubectl get pods -n devops-project
# NAME                        READY   STATUS    RESTARTS
# frontend-xxxxxxxxx-xxxxx    1/1     Running   0
# backend-xxxxxxxxx-xxxxx     1/1     Running   0
```

---

## 🔧 Before First Deploy — Required Setup

### Update your DockerHub username
In both deployment files, replace `YOUR_DOCKERHUB_USERNAME`:

```bash
# apps/frontend/deployment.yaml
image: YOUR_DOCKERHUB_USERNAME/devops-project-frontend:latest

# apps/backend/deployment.yaml
image: YOUR_DOCKERHUB_USERNAME/devops-project-backend:latest
```

### Update your domain
In `infra/ingress.yaml`:
```yaml
- host: yourdomain.com        # → your actual domain
- host: api.yourdomain.com    # → your actual domain
```

In `apps/frontend/configmap.yaml`:
```yaml
api_url: "https://api.yourdomain.com"  # → your actual domain
```

### Update ACM Certificate ARN
In `infra/ingress.yaml`:
```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/CERT_ID
```

---

## 🔒 Security Features in K8s Manifests

| Feature | Details |
|---------|---------|
| **Non-root containers** | `runAsUser: 1001`, `runAsNonRoot: true` |
| **Read-only filesystem** | `readOnlyRootFilesystem: true` (backend) |
| **Drop all capabilities** | `capabilities: drop: [ALL]` |
| **NetworkPolicies** | Pod-to-pod traffic restricted (zero-trust) |
| **RBAC** | Minimal ServiceAccount permissions |
| **AWS Secrets Manager** | No plaintext secrets in YAML files |
| **HPA** | Auto-scales 2–8 pods under load |
| **Rolling Updates** | `maxUnavailable: 0` — zero downtime |
| **Health Probes** | liveness + readiness + startup probes |
| **Topology Spread** | Pods spread across AZs |

---

<div align="center">

Part of the **[DevSecOps 3-Tier Project](https://github.com/YOUR_USERNAME/3-tier-devsecops)**

</div>
