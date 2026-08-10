variable "name_prefix"      { type = string }
variable "vpc_id"           { type = string }
variable "public_subnet_id" { type = string }
variable "key_name"         { type = string }
variable "your_ip_cidr"     { type = string }
variable "common_tags"      { type = map(string) }

variable "instance_type" {
  type        = string
  default     = "t3.large"
  description = "EC2 instance type for Jenkins (2 vCPU, 8GB RAM)"
}
