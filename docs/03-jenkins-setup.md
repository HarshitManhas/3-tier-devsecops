# Jenkins & SonarQube Setup Guide

## Table of Contents
1. [Ansible Execution](#ansible-execution)
2. [Jenkins Initial Configuration](#jenkins-initial-configuration)
3. [Jenkins Credentials](#jenkins-credentials)
4. [Tool Configurations](#tool-configurations)
5. [Pipeline Setup](#pipeline-setup)

## Ansible Execution
Run the Ansible playbooks to configure Jenkins, build tools, and SonarQube on the EC2 instance. Execute them in this order:
```bash
ansible-playbook -i inventory.ini tools-setup.yml
ansible-playbook -i inventory.ini jenkins-setup.yml
ansible-playbook -i inventory.ini sonarqube-setup.yml
```

## Jenkins Initial Configuration
1. Retrieve the initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
2. Navigate to `http://<JENKINS_IP>:8080`
3. Paste the password and select **Install suggested plugins**.
4. Complete the setup wizard by creating the first admin user.

### Required Plugins
Ensure the following plugins are installed (Manage Jenkins -> Manage Plugins):
- Docker Pipeline
- Amazon ECR plugin
- SonarQube Scanner
- Nodejs Plugin
- Git
- Pipeline

## Jenkins Credentials
Navigate to **Manage Jenkins -> Manage Credentials -> System -> Global credentials (unrestricted)** and add the following:

1. **aws-jenkins-credentials**: Type `AWS Credentials`, fill in your IAM Access Key and Secret Key.
2. **ECR_REGISTRY**: Type `Secret text`, value should be your ECR registry URL.
3. **github-gitops-creds**: Type `Secret text`, value should be your GitHub personal access token (PAT) for updating the GitOps repo.
4. **GITOPS_REPO_URL**: Type `Secret text`, value is the URL of your GitOps repository.

## Tool Configurations

### SonarQube Integration
1. Log in to SonarQube at `http://<JENKINS_IP>:9000` (default: admin/admin).
2. Generate a Webhook and an API token.
3. In Jenkins, go to **Manage Jenkins -> Configure System**.
4. Under **SonarQube servers**, click **Add SonarQube**.
   - Name: `SonarQube`
   - Server URL: `http://<JENKINS_IP>:9000`
   - Server authentication token: Add the SonarQube token as a Secret Text credential.

### Build Tools
Go to **Manage Jenkins -> Global Tool Configuration**:
- **NodeJS**: Click Add NodeJS, Name: `nodejs20`, select Install automatically and choose version 20.x.
- **SonarQube Scanner**: Click Add SonarQube Scanner, Name: `sonar-scanner`, Install automatically.

## Pipeline Setup
1. Create a new Item -> **Pipeline**, name it `devops-project`.
2. Scroll to Pipeline definition, select **Pipeline script from SCM**.
3. SCM: **Git**
4. Repository URL: Your main application repo URL.
5. Script Path: `Jenkinsfile`
6. Click **Save**.

### Test Pipeline Run
Click **Build Now** to trigger the first execution. Monitor the console output for any issues.
