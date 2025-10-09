#!/bin/bash

# ELK-Terraform-Challenge101 Master Installation Script
# This script orchestrates the sequential installation of all services

set -e  # Exit on any error
exec > >(tee -a /var/log/elk-terraform-install.log)
exec 2>&1

echo "🚀 Starting ELK-Terraform-Challenge101 Installation..."
echo "📅 $(date)"
echo "🖥️  Instance: $(hostname)"

# Update system
echo "📦 Updating system packages..."
yum update -y

# Install Docker and Docker Compose
echo "🐳 Installing Docker..."
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
echo "🔧 Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install additional tools
echo "🛠️  Installing additional tools..."
yum install -y git wget curl jq nc

# Create directories
echo "📁 Creating directory structure..."
mkdir -p /opt/elk-terraform/{config,logs,data,scripts}
cd /opt/elk-terraform

# Copy configuration files
echo "📋 Setting up configuration files..."

# Set environment variables from Terraform
export JENKINS_USER="${jenkins_user}"
export JENKINS_PASSWORD="${jenkins_password}"
export SONARQUBE_USER="${sonarqube_user}"
export SONARQUBE_PASSWORD="${sonarqube_password}"
export TOMCAT_USERNAME="${tomcat_username}"
export TOMCAT_PASSWORD="${tomcat_password}"

# Save environment variables
cat > /opt/elk-terraform/.env << EOF
JENKINS_USER=${jenkins_user}
JENKINS_PASSWORD=${jenkins_password}
SONARQUBE_USER=${sonarqube_user}
SONARQUBE_PASSWORD=${sonarqube_password}
TOMCAT_USERNAME=${tomcat_username}
TOMCAT_PASSWORD=${tomcat_password}
EOF

# Create health check script
cat > /opt/elk-terraform/scripts/health-checks.sh << 'EOF'
#!/bin/bash

# Health check functions
check_elasticsearch_health() {
    echo "🔍 Checking Elasticsearch health..."
    for i in {1..60}; do
        if curl -s -f "http://localhost:9200/_cluster/health" | grep -q '"status":"green\|yellow"'; then
            echo "✅ Elasticsearch is healthy"
            return 0
        fi
        echo "⏳ Waiting for Elasticsearch... ($i/60)"
        sleep 10
    done
    echo "❌ Elasticsearch health check failed"
    return 1
}

check_logstash_health() {
    echo "🔍 Checking Logstash health..."
    for i in {1..30}; do
        if nc -z localhost 5044; then
            echo "✅ Logstash is healthy"
            return 0
        fi
        echo "⏳ Waiting for Logstash... ($i/30)"
        sleep 10
    done
    echo "❌ Logstash health check failed"
    return 1
}

check_kibana_health() {
    echo "🔍 Checking Kibana health..."
    for i in {1..30}; do
        if curl -s -f "http://localhost:5601/api/status" | grep -q '"level":"available"'; then
            echo "✅ Kibana is healthy"
            return 0
        fi
        echo "⏳ Waiting for Kibana... ($i/30)"
        sleep 10
    done
    echo "❌ Kibana health check failed"
    return 1
}

check_jenkins_health() {
    echo "🔍 Checking Jenkins health..."
    for i in {1..30}; do
        if curl -s -f "http://localhost:8080/login" > /dev/null; then
            echo "✅ Jenkins is healthy"
            return 0
        fi
        echo "⏳ Waiting for Jenkins... ($i/30)"
        sleep 10
    done
    echo "❌ Jenkins health check failed"
    return 1
}

check_sonarqube_health() {
    echo "🔍 Checking SonarQube health..."
    for i in {1..60}; do
        if curl -s -f "http://localhost:9000/api/system/health" | grep -q '"health":"GREEN"'; then
            echo "✅ SonarQube is healthy"
            return 0
        fi
        echo "⏳ Waiting for SonarQube... ($i/60)"
        sleep 10
    done
    echo "❌ SonarQube health check failed"
    return 1
}

check_tomcat_health() {
    echo "🔍 Checking Tomcat health..."
    for i in {1..30}; do
        if curl -s -f "http://localhost:8081" > /dev/null; then
            echo "✅ Tomcat is healthy"
            return 0
        fi
        echo "⏳ Waiting for Tomcat... ($i/30)"
        sleep 10
    done
    echo "❌ Tomcat health check failed"
    return 1
}

# Main health check function
case "$1" in
    elasticsearch) check_elasticsearch_health ;;
    logstash) check_logstash_health ;;
    kibana) check_kibana_health ;;
    jenkins) check_jenkins_health ;;
    sonarqube) check_sonarqube_health ;;
    tomcat) check_tomcat_health ;;
    elk) 
        check_elasticsearch_health && check_logstash_health && check_kibana_health
        ;;
    all)
        check_elasticsearch_health && check_logstash_health && check_kibana_health && \
        check_jenkins_health && check_sonarqube_health && check_tomcat_health
        ;;
    *)
        echo "Usage: $0 {elasticsearch|logstash|kibana|jenkins|sonarqube|tomcat|elk|all}"
        exit 1
        ;;
esac
EOF

chmod +x /opt/elk-terraform/scripts/health-checks.sh

# Download and set up all installation scripts
echo "📥 Setting up installation scripts..."

# Create all installation scripts inline
cat > /opt/elk-terraform/scripts/install-elk.sh << 'INSTALL_ELK_EOF'
${file("${path.module}/scripts/install-elk.sh")}
INSTALL_ELK_EOF

cat > /opt/elk-terraform/scripts/install-jenkins.sh << 'INSTALL_JENKINS_EOF'
${file("${path.module}/scripts/install-jenkins.sh")}
INSTALL_JENKINS_EOF

cat > /opt/elk-terraform/scripts/install-sonarqube.sh << 'INSTALL_SONARQUBE_EOF'
${file("${path.module}/scripts/install-sonarqube.sh")}
INSTALL_SONARQUBE_EOF

cat > /opt/elk-terraform/scripts/install-tomcat.sh << 'INSTALL_TOMCAT_EOF'
${file("${path.module}/scripts/install-tomcat.sh")}
INSTALL_TOMCAT_EOF

cat > /opt/elk-terraform/scripts/setup-integrations.sh << 'SETUP_INTEGRATIONS_EOF'
${file("${path.module}/scripts/setup-integrations.sh")}
SETUP_INTEGRATIONS_EOF

# Make all scripts executable
chmod +x /opt/elk-terraform/scripts/*.sh

# Start sequential installation
echo "🎯 Starting sequential service installation..."
/opt/elk-terraform/scripts/master-install.sh