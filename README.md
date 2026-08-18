# 3-Tier DevSecOps Portfolio Project

This repository contains a complete 3-Tier Web Application (React + Node.js/Express + MySQL) deployed using a modern DevSecOps pipeline on AWS infrastructure. The project demonstrates Infrastructure as Code (IaC), GitOps, Continuous Integration (CI), Continuous Deployment (CD), and comprehensive Security Scanning.

## 🏗️ Architecture

![Architecture Diagram](<add architecture diagram screenshot here>)

### Infrastructure (AWS via Terraform)
*   **VPC**: Custom VPC with public and private subnets across two Availability Zones for high availability.
*   **EKS Cluster**: Amazon Elastic Kubernetes Service (v1.32) running in private subnets, managing the application workloads.
*   **RDS Database**: Amazon Relational Database Service (MySQL) in a private subnet, serving as the backend data store.
*   **Jenkins EC2**: A dedicated EC2 instance running Jenkins for CI/CD execution.
*   **SonarQube EC2**: A dedicated EC2 instance running SonarQube for static application security testing (SAST).
*   **NAT Gateways & Internet Gateways**: Enabling secure outbound internet access for resources in private subnets.
*   **ALB (Application Load Balancer)**: Exposing ArgoCD and the frontend application to the internet securely.

## 🛡️ Security Tools (DevSecOps)

The pipeline integrates several security checks to ensure code and image safety before deployment:

*   **Gitleaks**: Scans the repository for hardcoded secrets (API keys, passwords, tokens) before the build begins.
*   **SonarQube**: Performs Static Application Security Testing (SAST) to detect code quality issues, bugs, and vulnerabilities in the source code.
*   **Trivy (Filesystem)**: Scans the application dependencies (`package-lock.json`) for known vulnerabilities (CVEs).
*   **Trivy (Image)**: Scans the built Docker images for OS-level and application-level vulnerabilities before pushing to the registry.

## 🚀 CI/CD Pipeline (Jenkins + GitOps)

![Pipeline Run](<add Jenkins successful pipeline run screenshot here>)

The Jenkins CI pipeline is defined in the `Jenkinsfile` and performs the following stages:

1.  **Gitleaks Secret Scan**: Checks for accidentally committed secrets.
2.  **Install Dependencies**: Runs `npm install` for both frontend and backend.
3.  **Unit Tests**: Executes Jest test suites and generates code coverage reports.
4.  **SonarQube Analysis & Quality Gate**: Analyzes code quality and waits for the SonarQube Quality Gate to pass.
5.  **Trivy Filesystem Scan**: Checks dependencies for vulnerabilities.
6.  **Build Docker Images**: Builds Docker images for the frontend and backend.
7.  **Trivy Image Scan**: Scans the built images for vulnerabilities.
8.  **Push to DockerHub**: Pushes the secure images to the DockerHub registry.
9.  **Update GitOps Repo**: Updates the Kubernetes deployment manifests in a separate GitOps repository with the new image tags.

### Continuous Deployment (ArgoCD)

![ArgoCD Dashboard](<add ArgoCD dashboard screenshot here>)

Deployment is handled via the GitOps methodology using **ArgoCD**.
*   ArgoCD continuously monitors the GitOps repository.
*   When Jenkins updates the image tags in the GitOps repository, ArgoCD automatically detects the drift and syncs the changes to the EKS cluster.
*   This ensures the EKS cluster state always matches the declared state in Git.

## 📊 Monitoring & Observability

![Grafana Dashboard](<add Grafana dashboard screenshot here>)

The cluster and application are monitored using the **Kube-Prometheus-Stack** (deployed via Helm):
*   **Prometheus**: Scrapes and stores time-series metrics from the EKS cluster, worker nodes, and application pods.
*   **Grafana**: Provides data visualization and pre-built Kubernetes dashboards to monitor CPU, memory, network, and pod health.
*   **Alertmanager**: Configured to handle alerts for critical cluster events.

## 🛠️ Application Structure

*   `client/`: React frontend application.
*   `api/`: Node.js/Express backend API.
*   `terraform/`: Terraform configurations for provisioning AWS infrastructure.
*   `k8s/` or `apps/`: Kubernetes manifests (managed by ArgoCD).

## 🧑‍💻 Prerequisites

*   AWS Account with appropriate permissions.
*   Terraform installed.
*   AWS CLI installed and configured.
*   Docker installed.
*   Jenkins server.
*   SonarQube server.
*   DockerHub account.
*   GitHub account.

## 📝 Setup Instructions

1.  **Infrastructure Provisioning**:
    *   Navigate to the `terraform/environments/prod` directory.
    *   Update `terraform.tfvars` with your specific values (passwords, region, etc.).
    *   Run `terraform init`, `terraform plan`, and `terraform apply` to provision the AWS resources.
2.  **Configure Jenkins**:
    *   Access the Jenkins UI.
    *   Install necessary plugins: NodeJS, SonarQube Scanner.
    *   Configure global tools (NodeJS, SonarQube Scanner).
    *   Add credentials:
        *   DockerHub (`dockerhub-creds`)
        *   GitHub for GitOps repo (`github-gitops-creds`)
        *   SonarQube token (`sonar-token`)
    *   Configure the SonarQube server details in Jenkins system configuration.
3.  **Configure ArgoCD**:
    *   Access the ArgoCD UI (via ALB endpoint or port-forwarding).
    *   Connect your GitOps repository to ArgoCD.
    *   Create an ArgoCD Application pointing to the directory containing your Kubernetes manifests (e.g., `apps/`).
4.  **Run the Pipeline**:
    *   Trigger a build in Jenkins.
    *   Monitor the pipeline stages.
    *   Once complete, verify the application deployment in ArgoCD and access the frontend.
5.  **Configure Monitoring**:
    *   Deploy the `kube-prometheus-stack` via Helm.
    *   Expose the Grafana service as a LoadBalancer.
    *   Log in to Grafana to view real-time cluster metrics.

## 🧹 Cleanup

To avoid incurring AWS charges, destroy the infrastructure when you are done:
```bash
cd terraform/environments/prod
terraform destroy --auto-approve
```
