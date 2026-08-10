# RDS MySQL Module

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.common_tags, { Name = "${var.name_prefix}-rds-subnet-group" })
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security group for RDS MySQL - only allow from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_sg_id]
    description     = "MySQL from EKS nodes only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-rds-sg" })
}

# Parameter Group for MySQL 8.0
resource "aws_db_parameter_group" "mysql8" {
  name   = "${var.name_prefix}-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  tags = var.common_tags
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier        = "${var.name_prefix}-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.mysql8.name

  multi_az               = false  # Set to true for production HA
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "${var.name_prefix}-mysql-final-snapshot"
  deletion_protection    = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring.arn

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-mysql" })
}

# Enhanced Monitoring Role
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.name_prefix}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Store RDS credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.name_prefix}/rds/credentials"
  description             = "RDS MySQL credentials for DevOps Project"
  recovery_window_in_days = 7
  tags                    = var.common_tags
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.main.address
    port     = 3306
    dbname   = var.db_name
  })
}
