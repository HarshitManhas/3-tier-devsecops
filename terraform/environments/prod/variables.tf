variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "devops-project"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

# VPC
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# EKS
variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_desired_nodes" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_min_nodes" {
  description = "Minimum EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum EKS worker nodes"
  type        = number
  default     = 4
}

# RDS
variable "rds_db_name" {
  description = "RDS database name"
  type        = string
  default     = "crud_app"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "rds_password" {
  description = "RDS master password (min 8 chars)"
  type        = string
  sensitive   = true
}

# Jenkins EC2
variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins (t3.large = 2vCPU, 8GB RAM)"
  type        = string
  default     = "t3.large"
}

# SonarQube EC2
variable "sonarqube_instance_type" {
  description = "EC2 instance type for SonarQube (t3.medium = 2vCPU, 4GB RAM)"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "your_ip_cidr" {
  description = "Your public IP in CIDR format e.g. 1.2.3.4/32"
  type        = string
}

variable "domain_name" {
  description = "Your domain name"
  type        = string
}
