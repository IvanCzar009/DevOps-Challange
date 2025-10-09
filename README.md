# ELK-Terraform-Challenge101

🚀 **One-Command CI/CD Infrastructure with ELK Stack, Jenkins, SonarQube & Tomcat**

This project creates a complete DevOps infrastructure on AWS EC2 with sequential installation, error handling, health checks, and automatic service integration.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS EC2 Instance                        │
│                 ELK-Terraform-Challenge101                  │
├─────────────────────────────────────────────────────────────┤
│  📊 ELK Stack          🔧 Jenkins          📈 SonarQube     │
│  ├── Elasticsearch    ├── Pipeline        ├── Code Analysis│
│  ├── Logstash        ├── Auto-Jobs       ├── Quality Gates│
│  └── Kibana          └── React Build     └── Integration  │
│                                                             │
│  🚀 Tomcat            🔗 Integrations     📋 Monitoring    │
│  ├── React App       ├── Jenkins-Sonar   ├── Health Checks│
│  ├── Manager         ├── ELK Logging     ├── Auto-Restart │
│  └── Deployment      └── Auto-Pipeline   └── Status Dash  │
└─────────────────────────────────────────────────────────────┘
```

## ⚡ Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform installed
- Your SSH key pair (`Pair06.pem`) in the project directory

### One Command Deployment

```bash
terraform init && terraform apply -auto-approve
```

**That's it!** ✨

## 🎯 What Happens Automatically

### 1. Infrastructure Creation
- ✅ EC2 instance `t3.2xlarge` with enhanced storage
- ✅ Security groups with all required ports
- ✅ SSH access with your key pair

### 2. Sequential Service Installation
1. **ELK Stack** (Elasticsearch → Logstash → Kibana)
2. **Jenkins** (with plugins and auto-configuration)
3. **SonarQube** (with PostgreSQL and project setup)
4. **Tomcat** (with manager access and deployment structure)

### 3. Automatic Integration
- ✅ Jenkins job `group6-react-app-pipeline` created
- ✅ SonarQube project `group6-react-app` created
- ✅ ELK Stack collecting logs from all services
- ✅ First pipeline build triggered automatically

### 4. Health Monitoring
- ✅ Health checks for all services
- ✅ Automatic restart capabilities
- ✅ Error handling and logging
- ✅ Status dashboard

## 🔗 Access URLs (After Deployment)

```
🌐 Service Access:
├── Jenkins:     http://YOUR-EC2-IP:8080
├── SonarQube:   http://YOUR-EC2-IP:9000
├── Kibana:      http://YOUR-EC2-IP:5601
├── Tomcat:      http://YOUR-EC2-IP:8081
└── React App:   http://YOUR-EC2-IP:8081/group6-react-app

🔑 Default Credentials (from .env):
├── Jenkins:    admin/admin
├── SonarQube:  admin/admin
└── Tomcat:     admin/admin
```

## 📊 CI/CD Pipeline Flow

```
🔄 Automatic Pipeline Execution:
1. Git Checkout → Code retrieved
2. Dependencies → npm install
3. Testing → npm test with coverage
4. SonarQube Analysis → Code quality scan
5. Quality Gate → Pass/fail check
6. Build → npm run build
7. Deploy → Deploy to Tomcat
8. Logging → All steps logged to ELK
```

## 🛠️ Management Commands

### Check Status
```bash
# SSH into your instance
ssh -i Pair06.pem ec2-user@YOUR-EC2-IP

# Check all services
/opt/elk-terraform/scripts/status-check.sh

# Health check specific service
/opt/elk-terraform/scripts/health-checks.sh jenkins
/opt/elk-terraform/scripts/health-checks.sh elk
/opt/elk-terraform/scripts/health-checks.sh all
```

### Restart Services
```bash
# Restart specific service
/opt/elk-terraform/scripts/restart-services.sh jenkins
/opt/elk-terraform/scripts/restart-services.sh sonarqube

# Restart all services
/opt/elk-terraform/scripts/restart-services.sh all
```

### View Logs
```bash
# Installation logs
tail -f /var/log/elk-terraform-install.log

# Docker logs
docker-compose -f /opt/elk-terraform/jenkins-compose.yml logs
```

## 🎯 Key Features

### ✅ Error Handling
- Comprehensive error checking at each step
- Automatic rollback on failures
- Detailed error logging

### ✅ Health Monitoring
- Real-time health checks for all services
- Automatic restart capabilities
- Service dependency management

### ✅ Sequential Installation
- ELK Stack installed first
- Each service waits for dependencies
- No race conditions or conflicts

### ✅ Automatic Integration
- Jenkins-SonarQube integration configured
- ELK log collection from all services
- Pipeline triggers automatically

## 📁 Project Structure

```
ELK-Terraform-Challenge/
├── .env                      # Your configuration
├── Pair06.pem               # Your SSH key
├── main.tf                  # Terraform main configuration
├── variables.tf             # Terraform variables
├── outputs.tf               # Terraform outputs
└── scripts/
    ├── user-data.sh         # EC2 initialization script
    ├── install-elk.sh       # ELK Stack installer
    ├── install-jenkins.sh   # Jenkins installer
    ├── install-sonarqube.sh # SonarQube installer
    ├── install-tomcat.sh    # Tomcat installer
    ├── setup-integrations.sh # Service integration
    ├── health-checks.sh     # Health monitoring
    ├── restart-services.sh  # Service management
    └── status-check.sh      # Status dashboard
```

## 🔧 Customization

### Modify Services
Edit the respective installation scripts in `scripts/` directory:
- `install-elk.sh` - ELK Stack configuration
- `install-jenkins.sh` - Jenkins plugins and jobs
- `install-sonarqube.sh` - SonarQube projects and rules
- `install-tomcat.sh` - Tomcat configuration

### Change Credentials
Update your `.env` file with new credentials before deployment.

### Scale Resources
Modify `variables.tf` to change instance types or add additional resources.

## 🚨 Troubleshooting

### Services Not Starting
```bash
# Check Docker status
sudo systemctl status docker

# Check specific service logs
docker logs jenkins
docker logs sonarqube
docker logs elasticsearch

# Restart problematic service
/opt/elk-terraform/scripts/restart-services.sh jenkins
```

### Network Issues
```bash
# Check security group settings in AWS Console
# Verify ports: 8080 (Jenkins), 9000 (SonarQube), 5601 (Kibana), 8081 (Tomcat)
```

### Pipeline Not Triggering
```bash
# Manually trigger from Jenkins UI
# Check Jenkins logs: docker logs jenkins
# Verify SonarQube integration
```

## 📞 Support

For issues or questions:
1. Check the installation logs: `/var/log/elk-terraform-install.log`
2. Run status check: `/opt/elk-terraform/scripts/status-check.sh`
3. Check individual service health
4. Review Docker container logs

## 🎉 Success Indicators

When everything is working correctly, you should see:
- ✅ All services responding to health checks
- ✅ Jenkins pipeline visible and executable
- ✅ SonarQube project created with analysis
- ✅ React app accessible via Tomcat
- ✅ Logs flowing into Kibana dashboards

---

**🚀 Ready to deploy? Run: `terraform init && terraform apply -auto-approve`**