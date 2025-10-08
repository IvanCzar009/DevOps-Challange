# Variables for customization
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0945610b37068d87a"  # Amazon Linux 2 AMI (update based on your region)
}

variable "key_name" {
  description = "Name of the EC2 Key Pair"
  type        = string
  default     = "Pair06"  # Based on your PEM file (Pair06.pem)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.2xlarge"  # Sufficient for Tomcat + GitLab + ELK (8 vCPUs, 32GB RAM)
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "ELK-Terraform"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"  # Change as needed
}

# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create a security group
resource "aws_security_group" "instance_sg" {
  name        = "${var.instance_name}-security-group"
  description = "Security group for ${var.instance_name}"

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict this to your IP for better security
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kibana
  ingress {
    description = "Kibana"
    from_port   = 5061
    to_port     = 5061
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Elasticsearch
  ingress {
    description = "Elasticsearch"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Logstash Beats
  ingress {
    description = "Logstash Beats"
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tomcat
  ingress {
    description = "Tomcat"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SonarQube
  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # GitLab (Custom Port 8081)
  ingress {
    description = "GitLab"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Custom Port 8083
  ingress {
    description = "Custom Port 8083"
    from_port   = 8083
    to_port     = 8083
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
    Name = "${var.instance_name}-sg"
  }
}

# Create EC2 instance
resource "aws_instance" "main_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name              = var.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # User data script from external file
  user_data = base64encode(file("${path.module}/user-data.sh"))

  # Root volume configuration
  root_block_device {
    volume_type = "gp3"
    volume_size = 50 
    encrypted   = true
    delete_on_termination = true
  }

  tags = {
    Name = var.instance_name
  }
}

# Elastic IP for the EC2 instance
resource "aws_eip" "main_eip" {
  domain = "vpc"
  
  # Associate with the EC2 instance
  instance = aws_instance.main_instance.id
  
  # Ensure the instance is created before the EIP
  depends_on = [aws_instance.main_instance]
  
  tags = {
    Name = "${var.instance_name}-eip"
    Type = "Production"
  }
}

# Output the instance details
output "instance_id" {
  value = aws_instance.main_instance.id
  description = "ID of the EC2 instance"
}

output "instance_public_ip" {
  value = aws_eip.main_eip.public_ip
  description = "Static public IP address (Elastic IP)"
}

output "instance_private_ip" {
  value = aws_instance.main_instance.private_ip
  description = "Private IP address of the EC2 instance"
}

output "instance_public_dns" {
  value = aws_eip.main_eip.public_dns
  description = "Public DNS name for the Elastic IP"
}

output "elastic_ip_allocation_id" {
  value = aws_eip.main_eip.allocation_id
  description = "Allocation ID of the Elastic IP"
}

# Service URLs output for easy access
output "service_urls" {
  value = {
    gitlab     = "http://${aws_eip.main_eip.public_ip}:8081"
    kibana     = "http://${aws_eip.main_eip.public_ip}:5061"
    sonarqube  = "http://${aws_eip.main_eip.public_ip}:9000"
    tomcat     = "http://${aws_eip.main_eip.public_ip}:8080"
    react_app  = "http://${aws_eip.main_eip.public_ip}:8080/group6-react-app"
  }
  description = "URLs to access all deployed services"
}