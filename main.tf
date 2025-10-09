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

  tags = {
    Name = var.instance_name
  }

  # Connection settings for remote-exec
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${path.module}/Pair06.pem")
    host        = self.public_ip
    timeout     = "10m"
  }

  # Copy all scripts to the instance
  provisioner "file" {
    source      = "${path.module}/scripts/"
    destination = "/tmp/scripts"
  }

  # Execute the installation
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y docker git wget curl jq nc",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -a -G docker ec2-user",
      
      # Install Docker Compose
      "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose",
      
      # Set up directories and environment
      "sudo mkdir -p /opt/elk-terraform/{config,logs,data,scripts}",
      "sudo cp -r /tmp/scripts/* /opt/elk-terraform/scripts/",
      "sudo chmod +x /opt/elk-terraform/scripts/*.sh",
      
      # Create environment file
      "sudo tee /opt/elk-terraform/.env << EOF",
      "JENKINS_USER=${var.jenkins_user}",
      "JENKINS_PASSWORD=${var.jenkins_password}",
      "SONARQUBE_USER=${var.sonarqube_user}",
      "SONARQUBE_PASSWORD=${var.sonarqube_password}",
      "TOMCAT_USERNAME=${var.tomcat_username}",
      "TOMCAT_PASSWORD=${var.tomcat_password}",
      "EOF",
      
      # Change ownership
      "sudo chown -R ec2-user:ec2-user /opt/elk-terraform",
      
      # Start the installation (run in background and redirect output)
      "cd /opt/elk-terraform",
      "nohup sudo /opt/elk-terraform/scripts/install.sh > /var/log/elk-terraform-install.log 2>&1 &",
      
      # Wait a moment for the process to start
      "sleep 10",
      "echo 'Installation started in background. Check /var/log/elk-terraform-install.log for progress.'"
    ]
  }
}