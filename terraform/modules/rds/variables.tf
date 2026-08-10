variable "name_prefix"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "db_name"            { type = string }
variable "db_username"        { type = string; sensitive = true }
variable "db_password"        { type = string; sensitive = true }
variable "instance_class"     { type = string }
variable "allocated_storage"  { type = number }
variable "eks_sg_id"          { type = string }
variable "common_tags"        { type = map(string) }
