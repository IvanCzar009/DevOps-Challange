#!/bin/bash

# Integration Helper Script
# This script provides common functions and resolves conflicts between tools

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    echo "Usage: source integration-helper.sh"
    exit 1
fi

# Global configuration
INTEGRATION_LOG="/var/log/integration.log"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Logging function
log_integration() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $INTEGRATION_LOG
}

# Check if service is already installed
is_service_installed() {
    local service=$1
    case $service in
        "docker")
            systemctl is-enabled docker &>/dev/null
            ;;
        "postgresql")
            systemctl is-enabled postgresql &>/dev/null
            ;;
        "java11")
            [ -d "/usr/lib/jvm/java-11-openjdk" ]
            ;;
        "java17")
            [ -d "/usr/lib/jvm/java-17-openjdk" ]
            ;;
        "elk")
            [ -f "/home/ec2-user/elk-stack/docker-compose.yml" ]
            ;;
        "gitlab")
            systemctl is-enabled gitlab-runsvdir &>/dev/null
            ;;
        "tomcat")
            systemctl is-enabled tomcat &>/dev/null
            ;;
        "sonarqube")
            systemctl is-enabled sonarqube &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Install Docker if not already installed
ensure_docker() {
    if ! is_service_installed "docker"; then
        log_integration "Installing Docker..."
        yum install -y docker
        systemctl start docker
        systemctl enable docker
        usermod -a -G docker ec2-user
        
        # Install Docker Compose
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        log_integration "Docker installed successfully"
    else
        log_integration "Docker already installed"
    fi
}

# Install PostgreSQL if not already installed
ensure_postgresql() {
    if ! is_service_installed "postgresql"; then
        log_integration "Installing PostgreSQL..."
        yum install -y postgresql postgresql-server postgresql-contrib
        postgresql-setup initdb
        systemctl enable postgresql
        systemctl start postgresql
        log_integration "PostgreSQL installed successfully"
    else
        log_integration "PostgreSQL already installed"
    fi
}

# Setup Java environment with multiple versions
setup_java_environment() {
    local primary_version=$1
    
    log_integration "Setting up Java environment with primary version: $primary_version"
    
    # Install Java 11 if needed
    if ! is_service_installed "java11"; then
        log_integration "Installing Java 11..."
        yum install -y java-11-openjdk java-11-openjdk-devel
    fi
    
    # Install Java 17 if needed
    if ! is_service_installed "java17"; then
        log_integration "Installing Java 17..."
        yum install -y java-17-openjdk java-17-openjdk-devel
    fi
    
    # Set primary JAVA_HOME
    case $primary_version in
        "11")
            export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
            ;;
        "17")
            export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
            ;;
    esac
    
    # Update system environment
    echo "export JAVA_HOME=\"$JAVA_HOME\"" > /etc/profile.d/java.sh
    echo "export JAVA11_HOME=\"/usr/lib/jvm/java-11-openjdk\"" >> /etc/profile.d/java.sh
    echo "export JAVA17_HOME=\"/usr/lib/jvm/java-17-openjdk\"" >> /etc/profile.d/java.sh
    
    log_integration "Java environment configured with JAVA_HOME=$JAVA_HOME"
}

# Create separate PostgreSQL databases
create_separate_databases() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3
    
    log_integration "Creating database: $db_name for user: $db_user"
    
    # Check if database already exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
        log_integration "Database $db_name already exists"
        return 0
    fi
    
    sudo -u postgres psql << EOF
CREATE USER $db_user WITH PASSWORD '$db_pass';
CREATE DATABASE $db_name OWNER $db_user;
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
\q
EOF

    log_integration "Database $db_name created successfully"
}

# Configure log shipping to ELK
setup_log_shipping() {
    local service_name=$1
    local log_paths=("${@:2}")
    
    if ! is_service_installed "elk"; then
        log_integration "ELK not installed, skipping log shipping setup for $service_name"
        return 0
    fi
    
    log_integration "Setting up log shipping for $service_name"
    
    # Install Filebeat if not already installed
    if ! command -v filebeat &> /dev/null; then
        curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.10.0-x86_64.rpm
        rpm -vi filebeat-8.10.0-x86_64.rpm
    fi
    
    # Create Filebeat configuration for the service
    cat > /etc/filebeat/inputs.d/${service_name}.yml << EOF
- type: log
  enabled: true
  paths:
$(for path in "${log_paths[@]}"; do echo "    - $path"; done)
  fields:
    service: $service_name
    environment: production
    server_ip: $PUBLIC_IP
  fields_under_root: true
  multiline.pattern: '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
  multiline.negate: true
  multiline.match: after
EOF
    
    # Restart Filebeat
    systemctl restart filebeat
    log_integration "Log shipping configured for $service_name"
}

# Create integration monitoring script
create_integration_monitor() {
    log_integration "Creating integration monitoring script"
    
    cat > /home/ec2-user/monitor-integration.sh << 'EOF'
#!/bin/bash

# Integration Monitoring Script
# Monitors all installed services and their integration

echo "DevOps Tools Integration Status"
echo "==============================="
echo "Timestamp: $(date)"
echo "Server IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""

# Check Docker
if systemctl is-active --quiet docker; then
    echo "✓ Docker: Running"
    echo "  - Containers: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | tail -n +2 | wc -l) active"
else
    echo "✗ Docker: Not running"
fi

# Check PostgreSQL
if systemctl is-active --quiet postgresql; then
    echo "✓ PostgreSQL: Running"
    DB_COUNT=$(sudo -u postgres psql -c "SELECT count(*) FROM pg_database WHERE datistemplate = false;" -t | xargs)
    echo "  - Databases: $DB_COUNT"
else
    echo "✗ PostgreSQL: Not running"
fi

# Check Java versions
if [ -d "/usr/lib/jvm/java-11-openjdk" ]; then
    echo "✓ Java 11: Installed"
fi
if [ -d "/usr/lib/jvm/java-17-openjdk" ]; then
    echo "✓ Java 17: Installed"
fi

echo ""
echo "Service Status:"
echo "==============="

# Check ELK Stack
if [ -f "/home/ec2-user/elk-stack/docker-compose.yml" ]; then
    cd /home/ec2-user/elk-stack
    if docker-compose ps | grep -q "Up"; then
        echo "✓ ELK Stack: Running"
        echo "  - Elasticsearch: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9200)"
        echo "  - Kibana: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5601)"
    else
        echo "✗ ELK Stack: Not running"
    fi
fi

# Check GitLab
if systemctl is-active --quiet gitlab-runsvdir; then
    echo "✓ GitLab: Running"
    echo "  - Web: $(curl -s -o /dev/null -w "%{http_code}" http://localhost)"
else
    echo "✗ GitLab: Not running"
fi

# Check Tomcat
if systemctl is-active --quiet tomcat; then
    echo "✓ Tomcat: Running"
    echo "  - Web: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)"
else
    echo "✗ Tomcat: Not running"
fi

# Check SonarQube
if systemctl is-active --quiet sonarqube; then
    echo "✓ SonarQube: Running"
    echo "  - Web: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000)"
else
    echo "✗ SonarQube: Not running"
fi

echo ""
echo "Integration Features:"
echo "===================="

# Check log shipping
if command -v filebeat &> /dev/null; then
    if systemctl is-active --quiet filebeat; then
        echo "✓ Log Shipping: Active (Filebeat)"
    else
        echo "✗ Log Shipping: Filebeat installed but not running"
    fi
else
    echo "✗ Log Shipping: Not configured"
fi

# Check network connectivity between services
echo ""
echo "Service Connectivity:"
echo "===================="

services=("elasticsearch:9200" "kibana:5601" "gitlab:80" "tomcat:8080" "sonarqube:9000")
for service in "${services[@]}"; do
    IFS=':' read -r name port <<< "$service"
    if nc -z localhost $port 2>/dev/null; then
        echo "✓ $name:$port - Reachable"
    else
        echo "✗ $name:$port - Not reachable"
    fi
done

echo ""
echo "Memory Usage:"
echo "============="
free -h

echo ""
echo "Disk Usage:"
echo "==========="
df -h / | tail -1

EOF

    chmod +x /home/ec2-user/monitor-integration.sh
    chown ec2-user:ec2-user /home/ec2-user/monitor-integration.sh
    
    log_integration "Integration monitoring script created"
}

# Create service integration endpoints
create_service_integrations() {
    log_integration "Creating service integration configurations"
    
    # Create integration configuration directory
    mkdir -p /opt/integration
    
    # ELK-GitLab integration webhook setup
    if is_service_installed "elk" && is_service_installed "gitlab"; then
        cat > /opt/integration/gitlab-elk-webhook.sh << 'EOF'
#!/bin/bash
# GitLab to ELK webhook integration
curl -X POST http://localhost:5044 \
  -H "Content-Type: application/json" \
  -d '{"service": "gitlab", "event": "webhook", "timestamp": "'$(date -Iseconds)'", "data": "'$1'"}'
EOF
        chmod +x /opt/integration/gitlab-elk-webhook.sh
    fi
    
    # SonarQube-GitLab integration
    if is_service_installed "sonarqube" && is_service_installed "gitlab"; then
        cat > /opt/integration/sonarqube-gitlab.properties << EOF
# SonarQube GitLab integration
sonar.gitlab.url=http://localhost
sonar.gitlab.user_token=
sonar.gitlab.project_id=
EOF
    fi
    
    # Tomcat-ELK integration (log4j configuration)
    if is_service_installed "tomcat" && is_service_installed "elk"; then
        cat > /opt/tomcat/lib/log4j2.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Appenders>
        <Console name="Console" target="SYSTEM_OUT">
            <PatternLayout pattern="%d{HH:mm:ss.SSS} [%t] %-5level %logger{36} - %msg%n"/>
        </Console>
        <Socket name="ELK" host="localhost" port="5000">
            <JsonLayout complete="false" compact="true" eventEol="true"/>
        </Socket>
    </Appenders>
    <Loggers>
        <Root level="info">
            <AppenderRef ref="Console"/>
            <AppenderRef ref="ELK"/>
        </Root>
    </Loggers>
</Configuration>
EOF
    fi
    
    log_integration "Service integrations configured"
}

# Main integration setup function
setup_integration() {
    log_integration "Starting integration setup"
    
    # Update system
    yum update -y
    yum install -y curl wget unzip jq nc
    
    # Create integration monitoring
    create_integration_monitor
    
    # Setup service integrations
    create_service_integrations
    
    log_integration "Integration setup completed"
}

log_integration "Integration helper loaded successfully"