#!/bin/bash

# DevOps Tools Auto-Installation Script for EC2 Instance
# This script will be executed as user-data during EC2 instance launch

set -e

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "========================================="
echo "Starting DevOps Tools installation at $(date)"
echo "========================================="

# Change to ec2-user home directory
cd /home/ec2-user

# Copy all installation scripts using SCP or create them inline
echo "Setting up installation scripts..."

# Make all scripts executable (files will be copied via SCP after instance launch)
echo "Making installation scripts executable..."
find . -name "*.sh" -exec chmod +x {} \;

# Step 1: Install all system dependencies
echo "Step 1: Installing system dependencies..."
./install-dependencies.sh

# Step 2: Install DevOps tools
echo "Step 2: Installing DevOps tools..."

# Install all tools automatically (ELK, GitLab, Tomcat, SonarQube)
# This will install everything with proper integration
echo "elk gitlab tomcat sonarqube" | ./install-tools.sh

# Step 3: Deploy React Application
echo "Step 3: Deploying React Application..."
chmod +x deploy-react-app.sh
./deploy-react-app.sh

# Step 4: Setup GitLab Integration (Background)
echo "Step 4: Setting up GitLab integration (in background)..."
chmod +x setup-gitlab-integration.sh
nohup ./setup-gitlab-integration.sh > /var/log/gitlab-integration.log 2>&1 &

# Step 5: Final system configuration
echo "Step 5: Final system configuration..."

# Create final status file
cat > /home/ec2-user/installation-complete.txt << EOF
=== DevOps Tools Installation Complete ===
Installation Date: $(date)
Server IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

Installed Tools:
✓ ELK Stack (Elasticsearch, Logstash, Kibana)
✓ GitLab CE with PostgreSQL
✓ Apache Tomcat 9
✓ SonarQube CE with PostgreSQL
✓ Group 6 React Application with CI/CD Pipeline

Access URLs:
- Group 6 React App: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/group6-react-app
- Kibana (ELK): http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5061
- GitLab: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081
- Tomcat Manager: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/manager/html
- SonarQube: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000

All tools are integrated with:
- Centralized logging to ELK Stack
- Shared PostgreSQL database server
- Proper Java version management
- Log rotation and monitoring

Check credentials and details:
- credentials-vault.txt (All credentials in one secure file)
- react-app-info.txt (React app deployment details)
- elk-info.txt
- gitlab-info.txt  
- tomcat-info.txt
- sonarqube-info.txt

Installation logs available at:
- /var/log/user-data.log
- /var/log/dependencies-install.log
- /var/log/tools-install.log
EOF

chown ec2-user:ec2-user /home/ec2-user/installation-complete.txt

echo "========================================="
echo "DevOps Tools installation completed at $(date)"
echo "========================================="
echo "All services should be starting up now."
echo "Check /home/ec2-user/installation-complete.txt for access details."
echo "Installation logs saved to /var/log/user-data.log"

# Optional: Reboot to ensure all services start properly
# echo "Rebooting system in 30 seconds to ensure all services start properly..."
# sleep 30
# reboot