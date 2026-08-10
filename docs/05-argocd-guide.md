# Argo CD & GitOps Guide

## Table of Contents
1. [Argo CD Installation](#argo-cd-installation)
2. [AWS Load Balancer Controller](#aws-load-balancer-controller)
3. [External Secrets Operator](#external-secrets-operator)
4. [GitOps Configuration](#gitops-configuration)
5. [Application Deployment](#application-deployment)
6. [Operations](#operations)

## Argo CD Installation
Install Argo CD in your EKS cluster:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace
```

## AWS Load Balancer Controller
1. Create IAM Policy and Role for the load balancer controller.
2. Install via Helm:
```bash
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=devops-project-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## External Secrets Operator
Install ESO to sync AWS Secrets to Kubernetes:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

### AWS Secrets Manager Setup
Create entries in AWS Secrets Manager:
```bash
aws secretsmanager create-secret --name db-credentials --secret-string '{"username":"admin","password":"securepassword"}'
aws secretsmanager create-secret --name app-secrets --secret-string '{"jwt_secret":"my_super_secret_key"}'
```

## GitOps Configuration
Ensure your GitOps repository structure matches:
```text
gitops/
├── argocd/
│   ├── frontend-app.yaml
│   └── backend-app.yaml
├── k8s/
│   ├── frontend/
│   └── backend/
└── infra/
```

### Manifest Adjustments
Replace placeholders in `gitops/k8s/` before deploying:
- `<ACCOUNT_ID>`
- ECR URLs
- Your domain name and ACM cert ARN for Ingress

## Application Deployment
Apply the Argo CD App definitions:
```bash
kubectl apply -f gitops/argocd/
```

## Operations

### Access ArgoCD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Login with username `admin`. Get the password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Verification
In the UI, ensure all apps show as **Synced** and **Healthy**.

### Auto-Deploy
When Jenkins pushes a new image tag to the GitOps repository, Argo CD detects the commit, compares the cluster state, and automatically syncs the new image to EKS.

### Rollback
To rollback, either:
1. Revert the commit in the GitOps repository. Argo CD will sync backwards.
2. Use the Argo CD UI: Click **History and Rollback**, select the previous replica, and click **Rollback**.
