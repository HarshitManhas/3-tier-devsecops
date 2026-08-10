# SonarQube EC2 Module — Dedicated Server
# Runs: SonarQube + PostgreSQL (via Docker Compose)
# Separate from Jenkins to avoid Elasticsearch memory conflicts

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "sonarqube" {
  name        = "${var.name_prefix}-sonarqube-sg"
  description = "SonarQube EC2 - SSH and SonarQube UI"
  vpc_id      = var.vpc_id

  # SSH from admin IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
    description = "SSH from admin IP"
  }

  # SonarQube UI from admin IP
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
    description = "SonarQube UI from admin IP"
  }

  # SonarQube API from Jenkins EC2 security group
  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [var.jenkins_sg_id]
    description     = "SonarQube API access from Jenkins"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-sonarqube-sg" })
}

# IAM Role (minimal - SonarQube only needs SSM for patching)
resource "aws_iam_role" "sonarqube" {
  name = "${var.name_prefix}-sonarqube-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "sonarqube_ssm" {
  role       = aws_iam_role.sonarqube.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sonarqube" {
  name = "${var.name_prefix}-sonarqube-profile"
  role = aws_iam_role.sonarqube.name
}

# SonarQube EC2 Instance
resource "aws_instance" "sonarqube" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.sonarqube.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.sonarqube.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  # Runs bootstrap-sonarqube.sh on first boot
  # Installs: Docker, SonarQube, PostgreSQL
  user_data = base64encode(file("${path.module}/bootstrap-sonarqube.sh"))

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-sonarqube"
    Role = "sonarqube"
  })
}

resource "aws_eip" "sonarqube" {
  instance = aws_instance.sonarqube.id
  domain   = "vpc"
  tags     = merge(var.common_tags, { Name = "${var.name_prefix}-sonarqube-eip" })
}
