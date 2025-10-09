terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Security Group for all services
resource "aws_security_group" "elk_terraform_sg" {
  name_prefix = "elk-terraform-challenge-"
  description = "Security group for ELK-Terraform-Challenge101"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kibana
  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Elasticsearch
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Logstash
  ingress {
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tomcat
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-security-group"
  }
}

# EC2 Instance
resource "aws_instance" "elk_terraform_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name              = var.key_name
  vpc_security_group_ids = [aws_security_group.elk_terraform_sg.id]
  
  # Enhanced storage for all services
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    jenkins_user        = var.jenkins_user
    jenkins_password    = var.jenkins_password
    sonarqube_user     = var.sonarqube_user
    sonarqube_password = var.sonarqube_password
    tomcat_username    = var.tomcat_username
    tomcat_password    = var.tomcat_password
  }))

  tags = {
    Name = var.instance_name
  }

  # Wait for instance to be ready
  provisioner "local-exec" {
    command = "echo 'Instance ${self.public_ip} is being configured...'"
  }
}