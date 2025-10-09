#!/bin/bash

# SonarQube Installation Script
set -e
source /opt/elk-terraform/.env

echo "📈 Installing SonarQube..."

# Create SonarQube configuration directory
mkdir -p /opt/elk-terraform/config/sonarqube
mkdir -p /opt/elk-terraform/data/sonarqube

# Create SonarQube Docker Compose file
cat > /opt/elk-terraform/sonarqube-compose.yml << 'EOF'
version: '3.8'

services:
  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-db
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - sonarqube_db_data:/var/lib/postgresql/data
    networks:
      - sonarqube-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar"]
      interval: 30s
      timeout: 10s
      retries: 5

  sonarqube:
    image: sonarqube:community
    container_name: sonarqube
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ports:
      - "9000:9000"
    networks:
      - sonarqube-network
      - elk-network
    depends_on:
      sonarqube-db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9000/api/system/health || exit 1"]
      interval: 60s
      timeout: 30s
      retries: 10

volumes:
  sonarqube_db_data:
    driver: local
  sonarqube_data:
    driver: local
  sonarqube_extensions:
    driver: local
  sonarqube_logs:
    driver: local

networks:
  sonarqube-network:
    driver: bridge
  elk-network:
    external: true
EOF

echo "🚀 Starting SonarQube..."
cd /opt/elk-terraform
docker-compose -f sonarqube-compose.yml up -d

echo "⏳ Waiting for SonarQube to be ready (this may take several minutes)..."
sleep 120

# Health check with extended timeout for SonarQube
if /opt/elk-terraform/scripts/health-checks.sh sonarqube; then
    echo "✅ SonarQube is running!"
    
    echo "🔑 Configuring SonarQube..."
    
    # Wait for SonarQube to be fully ready
    sleep 60
    
    # Change default admin password
    echo "🔒 Setting up SonarQube admin credentials..."
    curl -u admin:admin -X POST "http://localhost:9000/api/users/change_password" \
        -d "login=admin&password=$SONARQUBE_PASSWORD&previousPassword=admin" || true
    
    # Create project
    echo "📋 Creating SonarQube project..."
    sleep 10
    
    PROJECT_RESPONSE=$(curl -u "$SONARQUBE_USER:$SONARQUBE_PASSWORD" -X POST "http://localhost:9000/api/projects/create" \
        -d "name=group6-react-app&project=group6-react-app" 2>/dev/null || echo "")
    
    if [[ $PROJECT_RESPONSE == *"group6-react-app"* ]] || [[ $PROJECT_RESPONSE == *"already exists"* ]]; then
        echo "✅ SonarQube project created successfully!"
    else
        echo "⚠️ SonarQube project creation may have issues, but continuing..."
    fi
    
    # Generate authentication token for Jenkins integration
    echo "🔐 Generating authentication token..."
    TOKEN_RESPONSE=$(curl -u "$SONARQUBE_USER:$SONARQUBE_PASSWORD" -X POST "http://localhost:9000/api/user_tokens/generate" \
        -d "name=jenkins-token" 2>/dev/null || echo "")
    
    if [[ $TOKEN_RESPONSE == *"token"* ]]; then
        TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        echo "✅ Authentication token generated: $TOKEN"
        echo "SONAR_TOKEN=$TOKEN" >> /opt/elk-terraform/.env
    else
        echo "⚠️ Token generation may have issues, using password authentication"
    fi
    
    # Create quality gate
    echo "🎯 Setting up quality gate..."
    curl -u "$SONARQUBE_USER:$SONARQUBE_PASSWORD" -X POST "http://localhost:9000/api/qualitygates/create" \
        -d "name=ELK-Terraform-Gate" || true
    
    # Set up webhook for Jenkins integration
    echo "🔗 Setting up Jenkins webhook..."
    curl -u "$SONARQUBE_USER:$SONARQUBE_PASSWORD" -X POST "http://localhost:9000/api/webhooks/create" \
        -d "name=jenkins-webhook&url=http://host.docker.internal:8080/sonarqube-webhook/" || true
    
    echo "✅ SonarQube installation and configuration completed!"
    echo "🔗 SonarQube URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
    echo "👤 Username: $SONARQUBE_USER"
    echo "🔑 Password: $SONARQUBE_PASSWORD"
    echo "📋 Project: group6-react-app"
    
else
    echo "❌ SonarQube installation failed!"
    docker-compose -f sonarqube-compose.yml logs
    exit 1
fi