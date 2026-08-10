# DevSecOps Project Task List

## Phase 1 — Local Docker Setup (Secure)
- [x] Create project directory structure
- [ ] Write `.gitignore` (block .env files)
- [ ] Write `api/.env.example`
- [ ] Write `api/Dockerfile` (secure, non-root)
- [ ] Write `client/Dockerfile` (multi-stage nginx)
- [ ] Write `docker-compose.yml` (local dev)
- [ ] Write `docker-compose.prod.yml` (prod-like)
- [ ] Write `api/app.js` (full, fixed)
- [ ] Write `api/models/db.js` (full)
- [ ] Write `api/models/init.sql` (schema)
- [ ] Write `api/controllers/authController.js` (full)
- [ ] Write `api/controllers/userController.js` (full)
- [ ] Write `api/middleware/auth.js` (full)
- [ ] Write `api/routes/authRoutes.js`
- [ ] Write `api/routes/userRoutes.js`
- [ ] Write `api/package.json`
- [ ] Write client files (App.js, components, pages - rebranded)
- [ ] Write `.gitleaks.toml`
- [ ] Write `sonar-project.properties`

## Phase 2 — Terraform AWS Infrastructure
- [ ] Write `terraform/backend.tf`
- [ ] Write `terraform/modules/vpc/`
- [ ] Write `terraform/modules/eks/`
- [ ] Write `terraform/modules/ecr/`
- [ ] Write `terraform/modules/rds/`
- [ ] Write `terraform/modules/jenkins/`
- [ ] Write `terraform/environments/prod/`

## Phase 3 — Ansible Configuration
- [ ] Write `ansible/inventory/hosts.yml`
- [ ] Write `ansible/playbooks/jenkins-setup.yml`
- [ ] Write `ansible/playbooks/tools-setup.yml`
- [ ] Write `ansible/playbooks/sonarqube-setup.yml`
- [ ] Write `ansible/roles/*/`

## Phase 4 — Jenkins CI Pipeline
- [ ] Write `Jenkinsfile` (full CI pipeline)

## Phase 5 — GitOps Kubernetes Manifests
- [ ] Write `gitops/apps/namespace.yaml`
- [ ] Write `gitops/apps/frontend/`
- [ ] Write `gitops/apps/backend/`
- [ ] Write `gitops/infra/ingress.yaml`
- [ ] Write `gitops/infra/rbac.yaml`
- [ ] Write `gitops/infra/externalsecrets.yaml`
- [ ] Write `gitops/argocd/`
- [ ] Write `gitops/infra/monitoring/`

## Phase 6 — Documentation
- [ ] Write `docs/01-local-setup.md`
- [ ] Write `docs/02-aws-setup.md`
- [ ] Write `docs/03-jenkins-setup.md`
- [ ] Write `docs/04-pipeline-guide.md`
- [ ] Write `docs/05-argocd-guide.md`
- [ ] Write `docs/06-monitoring.md`
