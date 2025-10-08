#!/bin/bash

# Enhanced Deployment Script for Group 6 React App
# Integrates with GitLab CI/CD, Tomcat, SonarQube, and ELK Stack

set -e  # Exit on any error

echo "🚀 Starting Enhanced Deployment for Group 6 React App"
echo "=================================================="

# Configuration
APP_NAME="group6-react-app"
TOMCAT_URL=${TOMCAT_URL:-"http://localhost:8083"}
SONAR_URL=${SONAR_URL:-"http://localhost:9000"}
KIBANA_URL=${KIBANA_URL:-"http://localhost:5061"}
BUILD_DIR="$(pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to send logs to ELK Stack
send_to_elk() {
    local log_data="$1"
    curl -s -X POST "http://localhost:5044" \
         -H "Content-Type: application/json" \
         -d "$log_data" || log_warning "Failed to send logs to ELK Stack"
}

# Function to check service health
check_service() {
    local service_url="$1"
    local service_name="$2"
    
    log_info "Checking $service_name health..."
    if curl -s --max-time 10 "$service_url" > /dev/null 2>&1; then
        log_success "$service_name is running"
        return 0
    else
        log_error "$service_name is not accessible at $service_url"
        return 1
    fi
}

# Pre-deployment checks
log_info "Running pre-deployment checks..."

# Check if required services are running
SERVICES_OK=true
check_service "$TOMCAT_URL" "Tomcat" || SERVICES_OK=false
check_service "$SONAR_URL" "SonarQube" || SERVICES_OK=false
check_service "$KIBANA_URL" "Kibana" || SERVICES_OK=false

if [ "$SERVICES_OK" = false ]; then
    log_error "Some services are not running. Please start all required services."
    exit 1
fi

# Check if package.json exists
if [ ! -f "package.json" ]; then
    log_error "package.json not found. Are you in the React app directory?"
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    log_info "Installing npm dependencies..."
    npm install
    log_success "Dependencies installed"
fi

# Run tests
log_info "Running tests..."
npm test -- --coverage --watchAll=false || {
    log_error "Tests failed"
    exit 1
}
log_success "All tests passed"

# Build the application
log_info "Building React application..."
npm run build || {
    log_error "Build failed"
    exit 1
}
log_success "Build completed successfully"

# Create WAR file structure
log_info "Creating WAR file structure..."
WAR_DIR="/tmp/${APP_NAME}-war-${TIMESTAMP}"
mkdir -p "$WAR_DIR/WEB-INF"

# Copy build files
cp -r build/* "$WAR_DIR/"

# Create web.xml
cat > "$WAR_DIR/WEB-INF/web.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
         http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">
         
    <display-name>Group 6 React Application</display-name>
    
    <welcome-file-list>
        <welcome-file>index.html</welcome-file>
    </welcome-file-list>
    
    <!-- Handle React Router (SPA routing) -->
    <error-page>
        <error-code>404</error-code>
        <location>/index.html</location>
    </error-page>
    
    <!-- Security headers -->
    <filter>
        <filter-name>SecurityHeadersFilter</filter-name>
        <filter-class>org.apache.catalina.filters.HttpHeaderSecurityFilter</filter-class>
        <init-param>
            <param-name>hstsEnabled</param-name>
            <param-value>false</param-value>
        </init-param>
    </filter>
    <filter-mapping>
        <filter-name>SecurityHeadersFilter</filter-name>
        <url-pattern>/*</url-pattern>
    </filter-mapping>
</web-app>
EOF

# Create Maven pom.xml for WAR packaging
cat > "$WAR_DIR/pom.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.devops</groupId>
    <artifactId>$APP_NAME</artifactId>
    <version>1.0.$TIMESTAMP</version>
    <packaging>war</packaging>
    
    <name>Group 6 React Application</name>
    <description>React application packaged as WAR for Tomcat deployment</description>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>javax.servlet</groupId>
            <artifactId>javax.servlet-api</artifactId>
            <version>4.0.1</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
    
    <build>
        <finalName>$APP_NAME</finalName>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-war-plugin</artifactId>
                <version>3.2.3</version>
                <configuration>
                    <webXml>WEB-INF\web.xml</webXml>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Package WAR file
log_info "Packaging WAR file..."
cd "$WAR_DIR"
mvn clean package -q || {
    log_error "Failed to create WAR file"
    exit 1
}

WAR_FILE="$WAR_DIR/target/$APP_NAME.war"
if [ -f "$WAR_FILE" ]; then
    log_success "WAR file created: $WAR_FILE"
    WAR_SIZE=$(stat -f%z "$WAR_FILE" 2>/dev/null || stat -c%s "$WAR_FILE" 2>/dev/null || echo "unknown")
    log_info "WAR file size: $WAR_SIZE bytes"
else
    log_error "WAR file not found"
    exit 1
fi

# Get Tomcat credentials from vault or use defaults
if [ -f /opt/devops-vault/vault-helper.sh ]; then
    source /opt/devops-vault/vault-helper.sh
    TOMCAT_USER=$(get_credential "TOMCAT" "TOMCAT_ADMIN_USER")
    TOMCAT_PASSWORD=$(get_credential "TOMCAT" "TOMCAT_ADMIN_PASSWORD")
    log_info "Using vault-managed Tomcat credentials"
else
    TOMCAT_USER=${TOMCAT_USER:-"admin"}
    TOMCAT_PASSWORD=${TOMCAT_PASSWORD:-"admin123"}
    log_warning "Using default Tomcat credentials"
fi

# Deploy to Tomcat
log_info "Deploying to Tomcat..."

# Undeploy existing application
log_info "Undeploying existing application (if any)..."
curl -s -u "$TOMCAT_USER:$TOMCAT_PASSWORD" \
     "$TOMCAT_URL/manager/text/undeploy?path=/$APP_NAME" || log_info "No existing deployment found"

# Deploy new WAR file
log_info "Deploying new application..."
DEPLOY_RESPONSE=$(curl -s -u "$TOMCAT_USER:$TOMCAT_PASSWORD" \
                      -T "$WAR_FILE" \
                      "$TOMCAT_URL/manager/text/deploy?path=/$APP_NAME&update=true")

if echo "$DEPLOY_RESPONSE" | grep -q "OK"; then
    log_success "Deployment successful"
else
    log_error "Deployment failed: $DEPLOY_RESPONSE"
    exit 1
fi

# Wait for application to start
log_info "Waiting for application to start..."
sleep 15

# Verify deployment
APP_URL="$TOMCAT_URL/$APP_NAME"
log_info "Verifying deployment at $APP_URL..."

for i in {1..5}; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL")
    if [ "$HTTP_STATUS" = "200" ]; then
        log_success "Application is running! HTTP Status: $HTTP_STATUS"
        DEPLOYMENT_STATUS="SUCCESS"
        break
    else
        log_warning "Attempt $i: HTTP Status $HTTP_STATUS, retrying..."
        sleep 10
    fi
done

if [ "$HTTP_STATUS" != "200" ]; then
    log_error "Deployment verification failed. HTTP Status: $HTTP_STATUS"
    DEPLOYMENT_STATUS="FAILED"
fi

# Send deployment logs to ELK Stack
log_info "Logging deployment to ELK Stack..."
DEPLOYMENT_LOG=$(cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "application": "$APP_NAME",
  "deployment_id": "$TIMESTAMP",
  "status": "$DEPLOYMENT_STATUS",
  "app_url": "$APP_URL",
  "tomcat_url": "$TOMCAT_URL",
  "sonar_url": "$SONAR_URL/dashboard?id=$APP_NAME",
  "kibana_url": "$KIBANA_URL",
  "http_status": $HTTP_STATUS,
  "war_file_size": "$WAR_SIZE",
  "deployment_time": "$(date)",
  "build_directory": "$BUILD_DIR",
  "war_file_path": "$WAR_FILE"
}
EOF
)

send_to_elk "$DEPLOYMENT_LOG"

# Create deployment summary
log_info "Creating deployment summary..."
echo ""
echo "=================================================="
echo "🎯 DEPLOYMENT SUMMARY"
echo "=================================================="
echo "📅 Timestamp: $(date)"
echo "📦 Application: $APP_NAME"
echo "🆔 Deployment ID: $TIMESTAMP"
echo "✅ Status: $DEPLOYMENT_STATUS"
echo "🌐 Application URL: $APP_URL"
echo "📊 Tomcat Manager: $TOMCAT_URL/manager"
echo "🔍 SonarQube Dashboard: $SONAR_URL/dashboard?id=$APP_NAME"
echo "📈 Kibana Logs: $KIBANA_URL"
echo "📁 WAR File: $WAR_FILE ($WAR_SIZE bytes)"
echo "=================================================="

# Cleanup
log_info "Cleaning up temporary files..."
rm -rf "$WAR_DIR"
log_success "Cleanup completed"

# Final status
if [ "$DEPLOYMENT_STATUS" = "SUCCESS" ]; then
    log_success "🎉 React app deployment completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. 🌐 Visit your app: $APP_URL"
    echo "2. 📊 Check Tomcat status: $TOMCAT_URL/manager"
    echo "3. 🔍 Review code quality: $SONAR_URL/dashboard?id=$APP_NAME"
    echo "4. 📈 Monitor logs: $KIBANA_URL"
    echo ""
    exit 0
else
    log_error "❌ Deployment completed with issues"
    echo "Check the following:"
    echo "1. 🐱 Tomcat logs: $TOMCAT_URL/manager"
    echo "2. 📈 Application logs in Kibana: $KIBANA_URL"
    echo "3. 🔧 Application configuration"
    echo ""
    exit 1
fi