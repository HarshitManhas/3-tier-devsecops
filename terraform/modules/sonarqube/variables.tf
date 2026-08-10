variable "name_prefix"      { type = string }
variable "vpc_id"           { type = string }
variable "public_subnet_id" { type = string }
variable "key_name"         { type = string }
variable "your_ip_cidr"     { type = string }
variable "jenkins_sg_id"    { type = string; description = "Jenkins SG ID so it can reach SonarQube port 9000" }
variable "common_tags"      { type = map(string) }

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 for SonarQube (2 vCPU, 4GB RAM) - Elasticsearch needs at least 2GB"
}
