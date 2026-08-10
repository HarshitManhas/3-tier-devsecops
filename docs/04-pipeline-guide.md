# CI/CD Pipeline Guide

## Table of Contents
1. [Pipeline Overview](#pipeline-overview)
2. [Stage Details](#stage-details)
3. [Environment Variables & Credentials](#environment-variables--credentials)
4. [Operation & Monitoring](#operation--monitoring)
5. [Troubleshooting](#troubleshooting)

## Pipeline Overview

```text
+----------+   +----------+   +---------+   +-----------+   +----------+   +------------+   +---------+
| Gitleaks |-->| Install  |-->| Unit    |-->| SonarQube |-->| Docker   |-->| Trivy      |-->| GitOps  |
| Scan     |   | Dependencies | Tests   |   | SAST      |   | Build    |   | Image Scan |   | Update  |
+----------+   +----------+   +---------+   +-----------+   +----------+   +------------+   +---------+
                               |                            +----------+
                               |                            | Trivy FS |
                               +--------------------------->| Scan     |
                                                            +----------+
```

## Stage Details

### 1. Gitleaks
Scans the repository for hardcoded secrets and credentials.
- **Action**: Fails the build if secrets are detected.
- **Fix**: Remove the secret and use `.gitleaksignore` if it's a false positive.

### 2. Install Dependencies
Runs `npm install` in parallel for both frontend and backend directories.

### 3. Unit Tests
Executes unit tests and generates coverage reports.
- **Add Tests**: Place `*.test.js` files in the respective `tests` directories.

### 4. SonarQube SAST
Runs Static Application Security Testing.
- **Quality Gate**: The pipeline will wait for the SonarQube quality gate result. Fails if coverage is too low or bugs are too high.
- **Configure**: Adjust rules in the SonarQube UI.

### 5. Trivy FS Scan
Scans the local filesystem and dependencies for vulnerabilities.
- **Severities**: High, Critical.
- **Suppress False Positives**: Create a `.trivyignore` file.

### 6. Docker Build
Builds the frontend and backend Docker images.
- Uses multi-stage builds to keep image size minimal.

### 7. Trivy Image Scan
Scans the built Docker images.
- **Gate**: Will block deployment (fail build) if CRITICAL vulnerabilities are found.

### 8. ECR Push
Authenticates with AWS and pushes images to the configured ECR repository.

### 9. GitOps Update
Clones the GitOps repository, updates the Kubernetes manifest with the newly built image tag, commits, and pushes the change.

## Environment Variables & Credentials

### Environment Variables
- `AWS_REGION`: ap-south-1
- `APP_NAME`: devops-project

### Required Jenkins Credentials
- `aws-jenkins-credentials`: AWS IAM User
- `ECR_REGISTRY`: ECR URL
- `github-gitops-creds`: GitHub PAT
- `GITOPS_REPO_URL`: Repository containing manifests

## Operation & Monitoring

### Triggering Pipeline
- Webhook trigger on commit to `main` branch.
- Manual trigger via **Build Now** in Jenkins.

### Viewing Reports
- **SonarQube**: Accessible at the SonarQube UI linked in the Jenkins build sidebar.
- **Trivy**: Reports are archived as Jenkins build artifacts.

## Troubleshooting
- **Gitleaks Failure**: Run `gitleaks detect` locally to find the offending line.
- **Quality Gate Timeout**: Ensure the Jenkins SonarQube webhook is correctly configured.
- **GitOps Push Failed**: Verify GitHub PAT permissions include repo access.
