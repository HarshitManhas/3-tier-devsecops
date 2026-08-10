# DevOps Project — Complete DevSecOps Implementation

> **3-Tier Application** (React + Node.js + MySQL) → Production-grade DevSecOps on AWS EKS

[![Jenkins CI](https://img.shields.io/badge/CI-Jenkins-D24939?logo=jenkins)](docs/04-pipeline-guide.md)
[![Argo CD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)](docs/05-argocd-guide.md)
[![AWS EKS](https://img.shields.io/badge/Platform-AWS%20EKS-FF9900?logo=amazon-aws)](docs/02-aws-setup.md)
[![Security](https://img.shields.io/badge/Security-SonarQube%20%7C%20Trivy%20%7C%20Gitleaks-blue)](docs/04-pipeline-guide.md)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Developer Workflow                          │
│                                                                     │
│  git push → GitHub (App Repo) ──────────────────────────────────┐  │
│                                                                  │  │
│          Jenkins CI Pipeline                                     │  │
│  ┌───────────────────────────────────────────────────────────┐  │  │
│  │  1. Gitleaks  →  2. npm ci  →  3. Jest Tests             │  │  │
│  │  4. SonarQube →  5. Trivy FS→  6. Docker Build           │  │  │
│  │  7. Trivy Image→  8. ECR Push→  9. Update GitOps Repo    │  │  │
│  └─────────────────────────────────────────────┬─────────────┘  │  │
│                                                │                 │  │
│                             GitHub GitOps Repo ◄─────────────────┘  │
│                                                │                    │
│                            Argo CD (watches GitOps repo)            │
│                                                │                    │
│                         AWS EKS Cluster        │                    │
│                ┌──────────────────────────────▼────────────────┐   │
│                │  Namespace: devops-project                     │   │
│                │                                                │   │
│                │  ┌─────────────┐      ┌─────────────────┐    │   │
│                │  │  Frontend   │─────▶│    Backend API   │    │   │
│                │  │  (React)    │      │   (Node.js)      │    │   │
│                │  │  2 replicas │      │   2 replicas     │    │   │
│                │  └─────────────┘      └────────┬────────┘    │   │
│                │  ALB Ingress + ACM TLS          │              │   │
│                │  NetworkPolicies + RBAC         │              │   │
│                │  HPA (2-8 replicas)             ▼              │   │
│                └─────────────────────────────────────────────┐ │   │
│                                              AWS RDS MySQL 8.0 │ │   │
│                                              (Private Subnet)  │ │   │
│                                              Encrypted + HA    │ │   │
└────────────────────────────────────────────────────────────────┘   │
                                                                      │
│  Observability: Prometheus + Grafana + Loki                        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### 1. Local Development (Docker Compose)
```bash
git clone <your-fork-url>
cd 3-tier-devsecops

# Setup environment
cp api/.env.example api/.env
# Edit api/.env with your local MySQL credentials

# Start all services
docker-compose up -d

# Verify
curl http://localhost:5000/health    # Backend
open http://localhost:3000           # Frontend
```

### 2. AWS Infrastructure (Terraform)
```bash
# Prerequisites: AWS CLI configured, Terraform installed
# See docs/02-aws-setup.md for full guide

cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

### 3. Configure Jenkins Server (Ansible)
```bash
# Get Jenkins IP from terraform output
export JENKINS_IP=$(terraform output -raw jenkins_public_ip)

cd ansible
ansible-playbook playbooks/tools-setup.yml
ansible-playbook playbooks/jenkins-setup.yml
ansible-playbook playbooks/sonarqube-setup.yml
```

### 4. Deploy to EKS (Argo CD)
```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name devops-project-prod-eks

# Install Argo CD
helm install argocd argo/argo-cd -n argocd --create-namespace

# Deploy apps
kubectl apply -f gitops/argocd/
```

---

## Project Structure

```
3-tier-devsecops/
├── 📁 api/                          # Node.js/Express backend
│   ├── app.js                       # Entry point with security hardening
│   ├── controllers/                 # authController, userController
│   ├── middleware/auth.js           # JWT authentication
│   ├── models/db.js                 # MySQL connection pool
│   ├── models/init.sql              # Database schema
│   ├── routes/                      # authRoutes, userRoutes
│   ├── tests/auth.test.js           # Unit tests (Jest)
│   ├── .env.example                 # Config template (no secrets!)
│   └── Dockerfile                   # Multi-stage, non-root user
│
├── 📁 client/                       # React 19 frontend
│   ├── src/
│   │   ├── App.js                   # Router with ProtectedRoute
│   │   ├── pages/                   # Login, Register, Dashboard, NotFound
│   │   ├── components/              # Layout, ProtectedRoute
│   │   ├── context/AuthContext.js   # JWT auth state management
│   │   ├── axios.js                 # Axios with interceptors
│   │   └── styles.css               # Dark theme glassmorphism design
│   ├── nginx.conf                   # Security headers, SPA routing
│   └── Dockerfile                   # Multi-stage nginx, non-root
│
├── 📁 terraform/                    # AWS Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/                     # VPC, subnets, NAT, IGW (2 AZs)
│   │   ├── eks/                     # EKS 1.29, managed nodes, OIDC
│   │   ├── ecr/                     # ECR repos + lifecycle policies
│   │   ├── rds/                     # RDS MySQL 8.0 encrypted
│   │   └── jenkins/                 # EC2 Jenkins server
│   └── environments/prod/           # Root module, variables, outputs
│
├── 📁 ansible/                      # Server Configuration
│   ├── playbooks/
│   │   ├── tools-setup.yml          # Docker, AWS CLI, kubectl, Helm, Trivy, Gitleaks
│   │   ├── jenkins-setup.yml        # Jenkins LTS + plugins
│   │   └── sonarqube-setup.yml      # SonarQube via Docker Compose
│   └── inventory/hosts.yml
│
├── 📁 gitops/                       # Kubernetes Manifests (GitOps)
│   ├── apps/
│   │   ├── namespace.yaml
│   │   ├── frontend/                # Deployment, Service, HPA, NetworkPolicy
│   │   └── backend/                 # Deployment, Service, HPA, NetworkPolicy
│   ├── infra/
│   │   ├── ingress.yaml             # ALB + ACM TLS
│   │   ├── rbac.yaml                # ServiceAccounts, Roles
│   │   ├── externalsecrets.yaml     # AWS Secrets Manager integration
│   │   └── monitoring/              # Prometheus + Loki Helm values
│   └── argocd/                      # App-of-Apps pattern
│
├── 📁 docs/                         # Step-by-step guides
│   ├── 01-local-setup.md
│   ├── 02-aws-setup.md
│   ├── 03-jenkins-setup.md
│   ├── 04-pipeline-guide.md
│   ├── 05-argocd-guide.md
│   └── 06-monitoring.md
│
├── docker-compose.yml               # Local dev stack
├── Jenkinsfile                      # Full CI pipeline
├── .gitleaks.toml                   # Secret detection config
└── sonar-project.properties         # SonarQube project config
```

---

## Security Posture

| Layer | Tool | What It Does |
|-------|------|-------------|
| **Secret Scanning** | Gitleaks | Blocks commits/builds with exposed credentials |
| **SAST** | SonarQube | Static code analysis, quality gates |
| **Dependency Scan** | Trivy (FS) | Scans npm packages for CVEs |
| **Image Scan** | Trivy (Image) | Scans Docker images; blocks on CRITICAL |
| **Secrets at Rest** | AWS Secrets Manager | No k8s secret YAML files with plain-text values |
| **Network** | NetworkPolicies | Restricts pod-to-pod traffic (zero trust) |
| **RBAC** | K8s RBAC | Minimal ServiceAccount permissions |
| **Runtime** | Non-root containers | All containers run as UID 1001 |
| **TLS** | ACM + ALB | HTTPS everywhere, TLS 1.3 |
| **Headers** | nginx | X-Frame-Options, CSP, HSTS |

---

## CI/CD Pipeline Flow

```
git push
    │
    ▼
Jenkins Trigger
    │
    ├── 🔑 Gitleaks Secret Scan         (FAIL = stop immediately)
    ├── 📦 Install Dependencies         (parallel: frontend + backend)
    ├── 🧪 Jest Unit Tests + Coverage
    ├── 🔍 SonarQube SAST              (Quality Gate enforced)
    ├── 🛡️ Trivy Filesystem Scan        (CRITICAL CVEs = fail)
    ├── 🐳 Docker Build                 (multi-stage, parallel)
    ├── 🔬 Trivy Image Scan            (CRITICAL = fail)
    ├── ☁️ Push to AWS ECR
    └── 🔄 Update GitOps Repo          (bump image tag)
                                            │
                                            ▼
                                    Argo CD Detects Change
                                            │
                                            ▼
                                    Rolling Deploy to EKS
                                    (Zero-downtime)
```

---

## Documentation

| Guide | Description |
|-------|-------------|
| [01 - Local Setup](docs/01-local-setup.md) | Run the app locally with Docker Compose |
| [02 - AWS Setup](docs/02-aws-setup.md) | Provision AWS infrastructure with Terraform |
| [03 - Jenkins Setup](docs/03-jenkins-setup.md) | Configure Jenkins with Ansible |
| [04 - Pipeline Guide](docs/04-pipeline-guide.md) | CI pipeline walkthrough |
| [05 - Argo CD Guide](docs/05-argocd-guide.md) | GitOps deployment with Argo CD |
| [06 - Monitoring](docs/06-monitoring.md) | Prometheus + Grafana + Loki setup |

---

## Cost Estimate (ap-south-1)

| Service | Cost/Month |
|---------|------------|
| EKS Cluster | ~$73 |
| EKS Nodes (2x t3.medium) | ~$60 |
| NAT Gateway (2x) | ~$65 |
| RDS db.t3.micro | ~$15 |
| Jenkins EC2 t3.large | ~$60 |
| ECR Storage | ~$2 |
| **Total** | **~$275/month** |

> ⚠️ Run `terraform destroy` when not in use to avoid charges.

---

## Technologies

React 19 · Node.js 20 · MySQL 8.0 · Docker · Jenkins · Ansible · Terraform · AWS EKS · AWS ECR · AWS RDS · AWS Secrets Manager · Kubernetes · Argo CD · SonarQube · Trivy · Gitleaks · Prometheus · Grafana · Loki · Helm · nginx

---

## Original Source

Based on [jaiswaladi246/3-Tier-DevSecOps-Mega-Project](https://github.com/jaiswaladi246/3-Tier-DevSecOps-Mega-Project/tree/local-dev), enhanced with:
- Complete security hardening (removed exposed credentials)
- Production-grade Dockerfiles (multi-stage, non-root)
- Full Terraform infrastructure (6 modules)
- Ansible configuration management
- Complete Jenkins CI pipeline with security gates
- GitOps with Argo CD App-of-Apps pattern
- AWS Secrets Manager integration
- Kubernetes RBAC + NetworkPolicies
- Prometheus + Grafana + Loki observability
- Rebranded as **DevOps Project**
