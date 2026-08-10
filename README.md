# 🚀 DevSecOps 3-Tier Application on AWS EKS

<div align="center">

**Production-grade DevSecOps pipeline — React + Node.js + MySQL deployed on AWS EKS**
**with automated CI/CD, 5-layer security scanning, and GitOps delivery**

[![Jenkins CI](https://img.shields.io/badge/CI-Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)](Jenkinsfile)
[![Argo CD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)](gitops/argocd/)
[![AWS EKS](https://img.shields.io/badge/Platform-AWS%20EKS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](terraform/)
[![Docker](https://img.shields.io/badge/Registry-DockerHub-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com)
[![SonarQube](https://img.shields.io/badge/SAST-SonarQube-4E9BCD?style=for-the-badge&logo=sonarqube&logoColor=white)](sonar-project.properties)
[![Trivy](https://img.shields.io/badge/Scanner-Trivy-1904DA?style=for-the-badge&logo=aqua&logoColor=white)](Jenkinsfile)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](terraform/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 📦 Repositories

| Repo | Description |
|------|-------------|
| **[3-tier-devsecops](https://github.com/YOUR_USERNAME/3-tier-devsecops)** ← You are here | App code, Jenkinsfile, Terraform, Ansible, Dockerfiles |
| **[3-tier-devsecops-gitops](https://github.com/YOUR_USERNAME/3-tier-devsecops-gitops)** | Kubernetes manifests (watched by Argo CD) |

---

## 🏗️ Architecture

```
👨‍💻 Developer
    │  git push
    ▼
🐙 GitHub (App Repo)
    │  Webhook
    ▼
┌──────────────────────────────────┐      ┌─────────────────────────────┐
│   🔧 Jenkins EC2 (t3.large)      │      │   🟠 SonarQube EC2 (t3.med) │
│   :8080 — Runs all 9 stages      │─────►│   :9000 — SAST Analysis     │
│                                  │      │   PostgreSQL 15              │
│  Stage 1: Gitleaks secret scan   │      └─────────────────────────────┘
│  Stage 2: npm install (parallel) │
│  Stage 3: Jest unit tests        │      ┌─────────────────────────────┐
│  Stage 4: SonarQube SAST    ─────┘      │   🐋 DockerHub              │
│  Stage 5: Trivy FS scan          │─────►│   username/frontend:tag     │
│  Stage 6: Docker build           │      │   username/backend:tag      │
│  Stage 7: Trivy image scan       │      └─────────────────────────────┘
│  Stage 8: DockerHub push    ─────┘
│  Stage 9: GitOps update     ─────────► 🐙 GitHub (GitOps Repo)
└──────────────────────────────────┘              │
                                         Argo CD watches
                                                  │
                                                  ▼
                              ┌────────────────────────────────────┐
                    Internet  │        ☸️ AWS EKS Cluster           │
                    ─────────►│  ┌─────────┐     ┌─────────────┐  │
                    AWS ALB   │  │ React   │────►│  Node.js    │  │
                    HTTPS:443 │  │ Frontend│     │  Backend    │  │
                              │  └─────────┘     └──────┬──────┘  │
                              │                         │:3306     │
                              │              ┌──────────▼───────┐  │
                              │              │  AWS RDS MySQL   │  │
                              │              │  (Private Subnet)│  │
                              └──────────────┴──────────────────┴──┘
```

**Total time from `git push` to live in production: ~15 minutes**

---

## 🔐 Security Gates (Shift-Left)

Every `git push` passes through **5 automated security gates** before reaching production:

| # | Gate | Tool | Blocks Pipeline If... |
|---|------|------|-----------------------|
| 1️⃣ | **Secret Scanning** | Gitleaks | Any password/token/key found in code |
| 2️⃣ | **Unit Tests** | Jest | Any test fails |
| 3️⃣ | **Static Analysis (SAST)** | SonarQube | Quality Gate fails (bugs, vulnerabilities) |
| 4️⃣ | **Dependency Scan** | Trivy FS | CRITICAL CVE in node_modules |
| 5️⃣ | **Container Scan** | Trivy Image | CRITICAL CVE in Docker image |

> **Zero-tolerance policy:** Nothing with a CRITICAL vulnerability reaches DockerHub or production.

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| **Frontend** | React 19, React Router, Axios, nginx |
| **Backend** | Node.js 20, Express, JWT, bcrypt, MySQL2 |
| **Database** | MySQL 8.0 on AWS RDS (Multi-AZ) |
| **Containerisation** | Docker (multi-stage builds, non-root UID 1001) |
| **Registry** | DockerHub |
| **Orchestration** | Kubernetes on AWS EKS 1.29 |
| **CI** | Jenkins LTS (single-node EC2 t3.large) |
| **CD / GitOps** | Argo CD (App-of-Apps pattern) |
| **IaC** | Terraform (6 modules: VPC, EKS, RDS, Jenkins, SonarQube, ECR) |
| **Config Mgmt** | Ansible (bootstrap + verify playbooks) |
| **SAST** | SonarQube 10.4 (dedicated EC2 t3.medium) |
| **Security Scanning** | Trivy (FS + Image), Gitleaks |
| **Secrets** | AWS Secrets Manager + External Secrets Operator |
| **Monitoring** | Prometheus, Grafana, Loki, Helm |
| **Networking** | AWS ALB, ACM (TLS 1.3), K8s NetworkPolicies |
| **Region** | AWS ap-south-1 (Mumbai) |

---

## 📁 Project Structure

```
3-tier-devsecops/
├── 📁 api/                          # Node.js/Express Backend
│   ├── app.js                       # Server entry — CORS, JWT, health checks
│   ├── controllers/                 # authController.js, userController.js
│   ├── middleware/auth.js           # JWT Bearer token validation
│   ├── models/db.js                 # MySQL connection pool (SSL in prod)
│   ├── models/init.sql              # Database schema + user setup
│   ├── routes/                      # authRoutes.js, userRoutes.js
│   ├── tests/auth.test.js           # Jest unit tests
│   ├── .env.example                 # Config template (no secrets committed)
│   └── Dockerfile                   # Multi-stage, non-root, healthcheck
│
├── 📁 client/                       # React 19 Frontend
│   ├── src/
│   │   ├── pages/                   # Login, Register, UserDashboard, NotFound
│   │   ├── components/              # Layout.js, ProtectedRoute.js
│   │   ├── context/AuthContext.js   # JWT auth state (React Context)
│   │   ├── axios.js                 # Axios instance + 401 interceptor
│   │   └── styles.css               # Dark glassmorphism theme
│   ├── nginx.conf                   # Security headers, SPA routing, gzip
│   └── Dockerfile                   # Multi-stage: node build → nginx:alpine
│
├── 📁 terraform/                    # AWS Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/                     # VPC, 2 public + 2 private subnets, NAT, IGW
│   │   ├── eks/                     # EKS 1.29, managed node group, OIDC, IRSA
│   │   ├── jenkins/                 # EC2 t3.large, SG, IAM role, user_data
│   │   ├── sonarqube/               # EC2 t3.medium, SG (Jenkins-only :9000)
│   │   ├── rds/                     # MySQL 8.0, encrypted, Multi-AZ, private
│   │   └── ecr/                     # ECR repos (optional, using DockerHub)
│   └── environments/prod/           # Root module, tfvars.example, outputs
│
├── 📁 ansible/                      # Configuration Management
│   ├── playbooks/
│   │   ├── jenkins-setup.yml        # Verify Jenkins health + config
│   │   └── sonarqube-setup.yml      # Verify SonarQube health + config
│   └── inventory/hosts.yml          # Jenkins + SonarQube EC2 groups
│
├── 📁 gitops/                       # Kubernetes Manifests (GitOps Repo)
│   ├── apps/
│   │   ├── namespace.yaml           # devops-project namespace
│   │   ├── frontend/                # Deployment, Service, HPA, NetworkPolicy
│   │   └── backend/                 # Deployment, Service, HPA, NetworkPolicy
│   ├── infra/
│   │   ├── ingress.yaml             # AWS ALB + ACM TLS termination
│   │   ├── rbac.yaml                # ServiceAccounts + minimal RBAC roles
│   │   ├── externalsecrets.yaml     # Pull secrets from AWS Secrets Manager
│   │   └── monitoring/              # Prometheus + Grafana Helm values
│   └── argocd/                      # App-of-Apps pattern
│       ├── app-of-apps.yaml
│       └── apps/                    # frontend-app.yaml, backend-app.yaml
│
├── 📁 scripts/
│   ├── bootstrap-jenkins.sh         # Auto-installs all tools on Jenkins EC2
│   ├── bootstrap-sonarqube.sh       # Auto-installs SonarQube + PostgreSQL
│   ├── setup-secrets.sh             # Creates AWS Secrets Manager entries
│   └── eks-setup.sh                 # Full EKS post-deploy setup (ALB, ArgoCD, monitoring)
│
├── 📁 docs/                         # Step-by-step Guides
│   ├── 01-local-setup.md
│   ├── 02-aws-setup.md
│   ├── 03-jenkins-setup.md
│   ├── 04-pipeline-guide.md
│   ├── 05-argocd-guide.md
│   └── 06-monitoring.md
│
├── Jenkinsfile                      # 9-stage CI pipeline (DockerHub)
├── docker-compose.yml               # Local dev — all 3 services
├── sonar-project.properties         # SonarQube project config
└── .gitleaks.toml                   # Gitleaks secret detection rules
```

---

## ⚡ Quick Start — Local Development

```bash
# 1. Clone
git clone https://github.com/YOUR_USERNAME/3-tier-devsecops.git
cd 3-tier-devsecops

# 2. Set env vars
cp api/.env.example api/.env
# Edit api/.env — set DB_PASSWORD, JWT_SECRET

# 3. Run all 3 services
docker-compose up -d

# 4. Verify
curl http://localhost:5000/health    # {"status":"healthy"}
open http://localhost:3000           # React app
```

---

## ☁️ Deploy to AWS

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform ≥ 1.5 installed
- DockerHub account with 2 repos created

### Step 1 — Provision Infrastructure

```bash
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Fill in: rds_password, jenkins_key_name, your_ip_cidr, domain_name

terraform init
terraform plan
terraform apply        # ~15-20 mins → creates 2 EC2s + EKS + RDS + VPC
terraform output       # Save: jenkins_ip, sonarqube_ip
```

### Step 2 — Setup AWS Secrets

```bash
# Run on Jenkins EC2 (via SSH)
bash scripts/setup-secrets.sh
# Prompts for: RDS endpoint, DB password, JWT secret, admin credentials
# Creates entries in AWS Secrets Manager
```

### Step 3 — Setup EKS

```bash
# Run on Jenkins EC2
bash scripts/eks-setup.sh
# Installs: ALB Controller, External Secrets Operator, Argo CD, Prometheus+Grafana
```

### Step 4 — Configure Jenkins

1. Open `http://JENKINS_IP:8080`
2. Add credentials:

| ID | Kind | Value |
|----|------|-------|
| `dockerhub-creds` | Username + Password | DockerHub user + Access Token |
| `SONARQUBE_URL` | Secret text | `http://SONARQUBE_IP:9000` |
| `GITOPS_REPO_URL` | Secret text | GitOps repo HTTPS URL |
| `github-gitops-creds` | Username + Password | GitHub user + PAT |

3. Configure SonarQube server: `Manage Jenkins → System → SonarQube Servers`
4. Create Pipeline job pointing to this repo's `Jenkinsfile`

### Step 5 — Deploy!

```bash
# In Jenkins UI
Build Now → Watch 9 stages → Argo CD auto-deploys to EKS
```

---

## 🔄 CI/CD Pipeline — 9 Stages

```
git push
  │
  ▼ Jenkins starts automatically (webhook)
  │
  ├─ Stage 1 ── 🔑 Gitleaks         → scans for secrets in all files & git history
  ├─ Stage 2 ── 📦 npm install       → installs deps (frontend + backend parallel)
  ├─ Stage 3 ── 🧪 Jest Tests        → runs unit tests + generates coverage report
  ├─ Stage 4 ── 🔍 SonarQube        → SAST code analysis → Quality Gate check
  ├─ Stage 5 ── 🛡️ Trivy FS          → scans node_modules for CVEs
  ├─ Stage 6 ── 🐳 Docker Build      → multi-stage images (frontend + backend parallel)
  ├─ Stage 7 ── 🔬 Trivy Image       → scans Docker images for OS + lib CVEs
  ├─ Stage 8 ── 🐋 DockerHub Push    → pushes verified images to DockerHub
  └─ Stage 9 ── 🔄 GitOps Update     → bumps image tag in K8s manifests
                                           │
                                    Argo CD detects change
                                           │
                                    Rolling update on EKS
                                    (zero downtime ✅)
```

---

## 🔒 Security Posture

| Layer | Tool / Mechanism | Protection |
|-------|-----------------|------------|
| Source Code | **Gitleaks** | Blocks secrets in git history |
| Code Quality | **SonarQube** | SQL injection, XSS, OWASP Top 10 |
| Dependencies | **Trivy FS** | CVEs in npm packages |
| Containers | **Trivy Image** | CVEs in Docker layers + OS packages |
| Secrets | **AWS Secrets Manager** | No plaintext secrets anywhere |
| Network | **K8s NetworkPolicies** | Zero-trust pod communication |
| Auth | **JWT (HS256)** | Stateless, expiring tokens |
| Runtime | **Non-root UID 1001** | No privilege escalation |
| Transport | **ACM + ALB TLS 1.3** | Encrypted end-to-end |
| Headers | **nginx** | CSP, X-Frame-Options, HSTS |

---

## 💰 Cost Estimate (AWS ap-south-1)

| Service | Spec | Cost/Month |
|---------|------|-----------|
| EKS Cluster | Managed control plane | ~$73 |
| EKS Nodes | 2× t3.medium | ~$60 |
| NAT Gateway | 2× (Multi-AZ) | ~$65 |
| RDS MySQL | db.t3.micro, Multi-AZ | ~$30 |
| Jenkins EC2 | t3.large | ~$60 |
| SonarQube EC2 | t3.medium | ~$30 |
| **Total** | | **~$318/month** |

> ⚠️ Run `terraform destroy` when not in use to stop charges.

---

## 📖 Documentation

| Guide | Description |
|-------|-------------|
| [01 — Local Setup](docs/01-local-setup.md) | Run locally with Docker Compose |
| [02 — AWS Setup](docs/02-aws-setup.md) | Provision infrastructure with Terraform |
| [03 — Jenkins Setup](docs/03-jenkins-setup.md) | Configure Jenkins (plugins, credentials) |
| [04 — Pipeline Guide](docs/04-pipeline-guide.md) | CI pipeline walkthrough |
| [05 — Argo CD Guide](docs/05-argocd-guide.md) | GitOps deployment with Argo CD |
| [06 — Monitoring](docs/06-monitoring.md) | Prometheus + Grafana + Loki setup |

---

## 📊 Monitoring

- **Prometheus** — metrics collection from all pods + nodes
- **Grafana** — dashboards for CPU, memory, request rate, error rate
- **Loki** — centralised log aggregation from all containers

Access:
```bash
# Grafana
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
# Open: http://localhost:3000   Login: admin / DevOps@Grafana123
```

---

<div align="center">

**Built with ❤️ for learning and portfolio purposes**

React · Node.js · MySQL · Docker · Jenkins · Ansible · Terraform · AWS EKS · Kubernetes · Argo CD · SonarQube · Trivy · Gitleaks · Prometheus · Grafana · DockerHub

</div>
