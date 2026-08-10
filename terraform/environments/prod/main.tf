# DevOps Project — Production Environment
# 2 EC2s: Jenkins (t3.large) + SonarQube (t3.medium)
# Registry: DockerHub (no ECR needed)

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "devops-project-terraform-state-ap-south-1"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "devops-project-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ── VPC Module ────────────────────────────────────────────
module "vpc" {
  source       = "../../modules/vpc"
  name_prefix  = local.name_prefix
  common_tags  = local.common_tags
}

# ── ECR Module ─ REMOVED ─────────────────────────────
# We use DockerHub as the container registry.
# DockerHub is free, simple, and doesn't require Terraform.
# Images: docker.io/YOUR_USERNAME/devops-project-frontend
#         docker.io/YOUR_USERNAME/devops-project-backend
# Create DockerHub account at: https://hub.docker.com
# Then add 'dockerhub-creds' credential in Jenkins.

# ── EKS Module ────────────────────────────────────────────
module "eks" {
  source              = "../../modules/eks"
  name_prefix         = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  common_tags         = local.common_tags
}

# ── RDS Module ────────────────────────────────────────────
module "rds" {
  source             = "../../modules/rds"
  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_name            = var.rds_db_name
  db_username        = var.rds_username
  db_password        = var.rds_password
  common_tags        = local.common_tags
}

# ── Jenkins EC2 Module (Single Node) ───────────────────────
module "jenkins" {
  source           = "../../modules/jenkins"
  name_prefix      = local.name_prefix
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  instance_type    = var.jenkins_instance_type
  key_name         = var.jenkins_key_name
  your_ip_cidr     = var.your_ip_cidr
  common_tags      = local.common_tags
}

# ── SonarQube EC2 Module (Dedicated) ──────────────────────
module "sonarqube" {
  source           = "../../modules/sonarqube"
  name_prefix      = local.name_prefix
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  instance_type    = var.sonarqube_instance_type
  key_name         = var.jenkins_key_name
  your_ip_cidr     = var.your_ip_cidr
  jenkins_sg_id    = module.jenkins.sg_id
  common_tags      = local.common_tags
}

# ── Outputs ────────────────────────────────────────────────
output "jenkins_ip"       { value = module.jenkins.public_ip }
output "jenkins_url"      { value = module.jenkins.jenkins_url }
output "sonarqube_ip"     { value = module.sonarqube.public_ip }
output "sonarqube_url"    { value = module.sonarqube.sonarqube_url }
output "eks_cluster_name" { value = module.eks.cluster_name }
output "eks_endpoint"     { value = module.eks.cluster_endpoint }
output "rds_endpoint"     { value = module.rds.endpoint; sensitive = true }

# DockerHub images (after jenkins pipeline runs):
# output "dockerhub_frontend" = "docker.io/YOUR_USERNAME/devops-project-frontend"
# output "dockerhub_backend"  = "docker.io/YOUR_USERNAME/devops-project-backend"
