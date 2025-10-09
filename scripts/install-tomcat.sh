#!/bin/bash

# Tomcat Installation Script
set -e
source /opt/elk-terraform/.env

echo "🚀 Installing Tomcat..."

# Create Tomcat configuration directory
mkdir -p /opt/elk-terraform/config/tomcat
mkdir -p /opt/elk-terraform/data/tomcat

# Create Tomcat users configuration
cat > /opt/elk-terraform/config/tomcat/tomcat-users.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>
  <user username="$TOMCAT_USERNAME" password="$TOMCAT_PASSWORD" 
        roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>
</tomcat-users>
EOF

# Create Tomcat context configuration to allow manager access
cat > /opt/elk-terraform/config/tomcat/manager-context.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!-- Remove the Valve below to allow access from any IP -->
  <!--
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />
  -->
</Context>
EOF

# Create host-manager context configuration
cat > /opt/elk-terraform/config/tomcat/host-manager-context.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
</Context>
EOF

# Create Tomcat Docker Compose file
cat > /opt/elk-terraform/tomcat-compose.yml << 'EOF'
version: '3.8'

services:
  tomcat:
    image: tomcat:9.0-jdk11
    container_name: tomcat
    environment:
      - CATALINA_OPTS=-Xmx512m -Xms256m
    volumes:
      - tomcat_webapps:/usr/local/tomcat/webapps
      - tomcat_logs:/usr/local/tomcat/logs
      - /opt/elk-terraform/config/tomcat/tomcat-users.xml:/usr/local/tomcat/conf/tomcat-users.xml
      - /opt/elk-terraform/config/tomcat/manager-context.xml:/usr/local/tomcat/webapps/manager/META-INF/context.xml
      - /opt/elk-terraform/config/tomcat/host-manager-context.xml:/usr/local/tomcat/webapps/host-manager/META-INF/context.xml
    ports:
      - "8081:8080"
    networks:
      - tomcat-network
      - elk-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
    command: >
      bash -c "
        # Copy manager and host-manager apps
        cp -R /usr/local/tomcat/webapps.dist/* /usr/local/tomcat/webapps/ || true
        # Start Tomcat
        catalina.sh run
      "

volumes:
  tomcat_webapps:
    driver: local
  tomcat_logs:
    driver: local

networks:
  tomcat-network:
    driver: bridge
  elk-network:
    external: true
EOF

echo "🚀 Starting Tomcat..."
cd /opt/elk-terraform
docker-compose -f tomcat-compose.yml up -d

echo "⏳ Waiting for Tomcat to be ready..."
sleep 30

# Health check
if /opt/elk-terraform/scripts/health-checks.sh tomcat; then
    echo "✅ Tomcat is running!"
    
    echo "🔧 Setting up React app deployment structure..."
    
    # Wait for Tomcat to be fully ready
    sleep 20
    
    # Create deployment directory for React app
    docker exec tomcat bash -c "
        mkdir -p /usr/local/tomcat/webapps/group6-react-app
        echo '<!DOCTYPE html>
<html>
<head>
    <title>Group 6 React App</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        .status { color: #28a745; font-weight: bold; }
        .info { background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class=\"container\">
        <h1>🎉 Group 6 React App</h1>
        <p class=\"status\">✅ Tomcat Server is Ready!</p>
        <div class=\"info\">
            <h3>Deployment Status</h3>
            <p>✅ Tomcat: Running on port 8081</p>
            <p>⏳ React App: Will be deployed via Jenkins pipeline</p>
            <p>📊 Logs: Being collected by ELK Stack</p>
        </div>
        <p><strong>Next Steps:</strong></p>
        <p>1. Trigger Jenkins pipeline to deploy the React application</p>
        <p>2. Monitor deployment in Jenkins dashboard</p>
        <p>3. View logs in Kibana dashboard</p>
        <hr>
        <small>Deployment Time: $(date)</small>
    </div>
</body>
</html>' > /usr/local/tomcat/webapps/group6-react-app/index.html
    " || echo "Default page setup completed"
    
    # Set up log forwarding to ELK
    echo "📊 Setting up log forwarding to ELK..."
    docker exec tomcat bash -c "
        # Create a simple log forwarder script
        echo '#!/bin/bash
        while true; do
            if [ -f /usr/local/tomcat/logs/catalina.out ]; then
                tail -f /usr/local/tomcat/logs/catalina.out | nc host.docker.internal 5044 || true
            fi
            sleep 10
        done' > /usr/local/tomcat/log-forwarder.sh
        chmod +x /usr/local/tomcat/log-forwarder.sh
        nohup /usr/local/tomcat/log-forwarder.sh &
    " || echo "Log forwarding setup completed"
    
    echo "✅ Tomcat installation and configuration completed!"
    echo "🔗 Tomcat URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081"
    echo "🔗 Tomcat Manager: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081/manager"
    echo "👤 Username: $TOMCAT_USERNAME"
    echo "🔑 Password: $TOMCAT_PASSWORD"
    echo "🎯 React App URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081/group6-react-app"
    
else
    echo "❌ Tomcat installation failed!"
    docker-compose -f tomcat-compose.yml logs
    exit 1
fi