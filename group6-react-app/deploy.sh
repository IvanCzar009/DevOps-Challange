#!/bin/bash

# Group 6 React App Deployment Script
# This script builds the React app and deploys it to Tomcat

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR"
BUILD_DIR="$APP_DIR/build"
TOMCAT_WEBAPPS="/opt/tomcat/webapps"
WAR_NAME="group6-react"

echo "=== Group 6 React App Deployment Started ==="
echo "Timestamp: $(date)"
echo "App Directory: $APP_DIR"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed. Please install Node.js first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed. Please install npm first."
    exit 1
fi

echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# Navigate to app directory
cd "$APP_DIR"

# Install dependencies
echo "Installing dependencies..."
npm install

# Run tests (optional, comment out if not needed)
echo "Running tests..."
npm test -- --watchAll=false --passWithNoTests

# Build the application
echo "Building React application..."
npm run build

if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory not found. Build might have failed."
    exit 1
fi

# Create web.xml for Tomcat deployment
echo "Creating web.xml for Tomcat deployment..."
mkdir -p "$BUILD_DIR/WEB-INF"

cat > "$BUILD_DIR/WEB-INF/web.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
         http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">
  <display-name>Group 6 React Application</display-name>
  <description>Group 6 React Frontend for ELK Challenge</description>
  
  <welcome-file-list>
    <welcome-file>index.html</welcome-file>
  </welcome-file-list>
  
  <!-- Enable compression for static files -->
  <filter>
    <filter-name>CompressionFilter</filter-name>
    <filter-class>org.apache.catalina.filters.CompressionFilter</filter-class>
  </filter>
  <filter-mapping>
    <filter-name>CompressionFilter</filter-name>
    <url-pattern>/*</url-pattern>
  </filter-mapping>
  
  <!-- Cache control for static assets -->
  <filter>
    <filter-name>CacheControlFilter</filter-name>
    <filter-class>org.apache.catalina.filters.ExpiresFilter</filter-class>
    <init-param>
      <param-name>ExpiresByType text/css</param-name>
      <param-value>access plus 1 month</param-value>
    </init-param>
    <init-param>
      <param-name>ExpiresByType application/javascript</param-name>
      <param-value>access plus 1 month</param-value>
    </init-param>
    <init-param>
      <param-name>ExpiresByType image/png</param-name>
      <param-value>access plus 1 year</param-value>
    </init-param>
  </filter>
  <filter-mapping>
    <filter-name>CacheControlFilter</filter-name>
    <url-pattern>/*</url-pattern>
  </filter-mapping>
</web-app>
EOF

# Create build info file
echo "Creating build information..."
cat > "$BUILD_DIR/build-info.json" << EOF
{
  "buildTime": "$(date -Iseconds)",
  "version": "1.0.0",
  "commit": "${GIT_COMMIT:-unknown}",
  "branch": "${GIT_BRANCH:-unknown}",
  "environment": "production",
  "services": {
    "kibana": "http://localhost:5601",
    "gitlab": "http://localhost:8081",
    "tomcat": "http://localhost:8083",
    "elasticsearch": "http://localhost:9200"
  }
}
EOF

# Create WAR file
echo "Creating WAR file..."
cd "$BUILD_DIR"
jar -cf "../${WAR_NAME}.war" *
cd "$APP_DIR"

echo "WAR file created: ${APP_DIR}/${WAR_NAME}.war"
ls -la "${APP_DIR}/${WAR_NAME}.war"

# Deploy to Tomcat (if running locally)
if [ -d "$TOMCAT_WEBAPPS" ] && [ -w "$TOMCAT_WEBAPPS" ]; then
    echo "Deploying to local Tomcat..."
    
    # Stop Tomcat if running
    if systemctl is-active --quiet tomcat; then
        echo "Stopping Tomcat..."
        sudo systemctl stop tomcat
        sleep 5
    fi
    
    # Remove old deployment
    sudo rm -f "${TOMCAT_WEBAPPS}/${WAR_NAME}.war"
    sudo rm -rf "${TOMCAT_WEBAPPS}/${WAR_NAME}/"
    
    # Copy new WAR file
    sudo cp "${APP_DIR}/${WAR_NAME}.war" "$TOMCAT_WEBAPPS/"
    sudo chown tomcat:tomcat "${TOMCAT_WEBAPPS}/${WAR_NAME}.war"
    
    # Start Tomcat
    echo "Starting Tomcat..."
    sudo systemctl start tomcat
    
    # Wait for deployment
    echo "Waiting for application to deploy..."
    sleep 30
    
    # Test deployment
    if curl -f "http://localhost:8083/${WAR_NAME}/" > /dev/null 2>&1; then
        echo "✅ Application deployed successfully!"
        echo "🌐 Access your app at: http://localhost:8083/${WAR_NAME}/"
    else
        echo "⚠️  Application deployed but might still be starting up."
        echo "🌐 Try accessing: http://localhost:8083/${WAR_NAME}/"
    fi
else
    echo "ℹ️  Tomcat not found locally. WAR file created for manual deployment."
    echo "📦 WAR file location: ${APP_DIR}/${WAR_NAME}.war"
    echo "📋 Manual deployment steps:"
    echo "   1. Copy ${WAR_NAME}.war to your Tomcat webapps directory"
    echo "   2. Restart Tomcat"
    echo "   3. Access http://your-server:8083/${WAR_NAME}/"
fi

echo ""
echo "=== Deployment Summary ==="
echo "✅ React app built successfully"
echo "✅ WAR file created: ${WAR_NAME}.war"
echo "✅ Build info: $(cat "$BUILD_DIR/build-info.json" | grep buildTime)"
echo "=== Deployment Completed ==="