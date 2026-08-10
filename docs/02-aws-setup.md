# AWS Infrastructure Setup Guide

This guide walks you through provisioning the AWS infrastructure required for the DevOps Project.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [AWS CLI Configuration](#aws-cli-configuration)
3. [Terraform Setup](#terraform-setup)
4. [State Management](#state-management)
5. [Provisioning Infrastructure](#provisioning-infrastructure)
6. [Kubernetes Configuration](#kubernetes-configuration)
7. [Cost Estimates](#cost-estimates)
8. [Destroying Infrastructure](#destroying-infrastructure)

## Prerequisites
- An active AWS Account
- Billing alerts configured in AWS
- Administrator access

## AWS CLI Configuration
Install AWS CLI v2 for your OS:
- Windows/Mac/Linux instructions: [AWS CLI Setup](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

Configure your CLI to use `ap-south-1`:
```bash
aws configure
# Enter Access Key ID
# Enter Secret Access Key
# Default region name: ap-south-1
# Default output format: json
```

## Terraform Setup
Install Terraform. We recommend using `tfenv` to manage versions:
```bash
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile
tfenv install 1.5.7
tfenv use 1.5.7
```

## State Management
Create an S3 bucket and DynamoDB table for Terraform state and locking.
1. Go to AWS S3 and create a bucket (e.g., `devops-project-tf-state`).
2. Go to DynamoDB and create a table named `terraform-state-lock` with Partition Key `LockID` (String).

## Provisioning Infrastructure
1. Generate an EC2 key pair for node access:
```bash
aws ec2 create-key-pair --key-name devops-eks-key --query 'KeyMaterial' --output text > devops-eks-key.pem
chmod 400 devops-eks-key.pem
```
2. Navigate to the Terraform directory:
```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```
Update `terraform.tfvars` with your specific values.

3. Initialize and apply:
```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### Expected Outputs
- Jenkins EC2 IP
- EKS Cluster Endpoint
- ECR Repository URLs (frontend & backend)
- RDS MySQL Endpoint

## Kubernetes Configuration
Configure `kubectl` to communicate with your EKS cluster:
```bash
aws eks update-kubeconfig --region ap-south-1 --name devops-project-cluster
```
Verify the nodes:
```bash
kubectl get nodes
```

## Cost Estimates
Estimated monthly costs (ap-south-1):
- EKS Control Plane: ~$73
- EC2 Worker Nodes (t3.medium x2): ~$60
- RDS MySQL (db.t3.micro): ~$15
- NAT Gateway: ~$32
- **Total Estimated**: ~$180/month

## Destroying Infrastructure
To tear down the environment:
```bash
terraform destroy -auto-approve
```
> **Warning**: This action is irreversible.
