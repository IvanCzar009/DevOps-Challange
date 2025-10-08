#!/bin/bash

# Apache Tomcat Installation Script
# Installs Apache Tomcat 9 with Java 11

set -e

# Log all output
exec > >(tee /var/log/tomcat-installation.log) 2>&1

echo "Starting Apache Tomcat installation at $(date)"

# Get public IP for configuration
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Instance Public IP: $PUBLIC_IP"

# Configuration variables (will be updated if local tar.gz found)
TOMCAT_VERSION="9.0.82"
TOMCAT_USER="tomcat"
TOMCAT_HOME="/opt/tomcat"
TOMCAT_PORT="8080"
TOMCAT_ADMIN_USER="admin"
TOMCAT_ADMIN_PASS="TomcatAdmin2024!"

# Generate random password if not set
if [ -z "$TOMCAT_ADMIN_PASS" ] || [ "$TOMCAT_ADMIN_PASS" = "TomcatAdmin2024!" ]; then
    TOMCAT_ADMIN_PASS="TomcatAdmin2024_$(date +%s | tail -c 6)"
fi

# Load integration helper if available
if [ -f "$(dirname "$0")/integration-helper.sh" ]; then
    source "$(dirname "$0")/integration-helper.sh"
fi

# Update system
echo "Updating system packages..."
yum update -y

# Setup Java environment (using integration helper)
if command -v setup_java_environment &> /dev/null; then
    setup_java_environment "11"
    export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
else
    # Fallback installation
    echo "Installing Java 11..."
    yum install -y java-11-openjdk java-11-openjdk-devel
    export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
    echo 'export JAVA_HOME="/usr/lib/jvm/java-11-openjdk"' >> /etc/environment
fi

# Create tomcat user
echo "Creating tomcat user..."
useradd -m -U -d $TOMCAT_HOME -s /bin/false $TOMCAT_USER

# Install Tomcat from local tar.gz or download if not available
echo "Looking for local Tomcat tar.gz file..."
cd /home/ec2-user

# Look for Tomcat tar.gz files in the current directory
TOMCAT_TAR_FILE=""
DETECTED_VERSION=""

# Check for different possible Tomcat archive names
for pattern in "apache-tomcat-*.tar.gz" "tomcat-*.tar.gz" "*.tar.gz"; do
    for file in $pattern; do
        if [ -f "$file" ]; then
            # Check if this is likely a Tomcat archive
            if echo "$file" | grep -qi "tomcat" || tar -tzf "$file" 2>/dev/null | head -1 | grep -qi "tomcat"; then
                TOMCAT_TAR_FILE="$file"
                echo "Found local Tomcat archive: $file"
                
                # Try to extract version from filename
                if echo "$file" | grep -q "apache-tomcat-"; then
                    DETECTED_VERSION=$(echo "$file" | sed 's/apache-tomcat-\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/')
                elif echo "$file" | grep -q "tomcat-"; then
                    DETECTED_VERSION=$(echo "$file" | sed 's/tomcat-\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/')
                fi
                
                if [ -n "$DETECTED_VERSION" ]; then
                    echo "Detected Tomcat version: $DETECTED_VERSION"
                    TOMCAT_VERSION="$DETECTED_VERSION"
                fi
                break 2
            fi
        fi
    done
done

# If no local file found, download it
if [ -z "$TOMCAT_TAR_FILE" ]; then
    echo "No local Tomcat tar.gz found, downloading Apache Tomcat $TOMCAT_VERSION..."
    wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
    TOMCAT_TAR_FILE="apache-tomcat-$TOMCAT_VERSION.tar.gz"
fi

echo "Installing Apache Tomcat from: $TOMCAT_TAR_FILE"

# Extract and install Tomcat
TEMP_DIR="/tmp/tomcat-install-$$"
mkdir -p $TEMP_DIR

echo "Extracting Tomcat archive..."
if ! tar -xf "$TOMCAT_TAR_FILE" -C $TEMP_DIR; then
    echo "Error: Failed to extract $TOMCAT_TAR_FILE"
    rm -rf $TEMP_DIR
    exit 1
fi

# Find the extracted directory (handle different archive structures)
echo "Looking for extracted Tomcat directory..."
EXTRACTED_DIR=""

# Look for common Tomcat directory patterns
for pattern in "*tomcat*" "*apache*" "*/"; do
    DIR=$(find $TEMP_DIR -maxdepth 1 -type d -name "$pattern" | grep -v "^$TEMP_DIR$" | head -1)
    if [ -n "$DIR" ] && [ -f "$DIR/bin/catalina.sh" ]; then
        EXTRACTED_DIR="$DIR"
        break
    fi
done

# If still not found, look for any directory with Tomcat binaries
if [ -z "$EXTRACTED_DIR" ]; then
    for dir in $TEMP_DIR/*/; do
        if [ -f "$dir/bin/catalina.sh" ] || [ -f "$dir/bin/startup.sh" ]; then
            EXTRACTED_DIR="$dir"
            break
        fi
    done
fi

if [ -z "$EXTRACTED_DIR" ]; then
    echo "Error: Could not find valid Tomcat directory in archive"
    echo "Archive contents:"
    ls -la $TEMP_DIR/
    rm -rf $TEMP_DIR
    exit 1
fi

echo "Found extracted directory: $EXTRACTED_DIR"

# Verify this is a valid Tomcat installation
if [ ! -f "$EXTRACTED_DIR/bin/catalina.sh" ]; then
    echo "Error: Invalid Tomcat installation - missing catalina.sh"
    rm -rf $TEMP_DIR
    exit 1
fi

# Create Tomcat home directory and copy files
echo "Installing Tomcat to $TOMCAT_HOME..."
mkdir -p $TOMCAT_HOME
cp -r $EXTRACTED_DIR/* $TOMCAT_HOME/

# Verify installation
if [ ! -f "$TOMCAT_HOME/bin/catalina.sh" ]; then
    echo "Error: Tomcat installation failed - missing catalina.sh in $TOMCAT_HOME"
    rm -rf $TEMP_DIR
    exit 1
fi

# Set proper ownership and permissions
chown -R $TOMCAT_USER: $TOMCAT_HOME
chmod +x $TOMCAT_HOME/bin/*.sh

# Clean up temporary directory
rm -rf $TEMP_DIR

echo "Tomcat installation completed successfully!"
echo "Installed version: $TOMCAT_VERSION"
echo "Installation directory: $TOMCAT_HOME"

echo "Tomcat installation completed from: $TOMCAT_TAR_FILE"

# Configure Tomcat users
echo "Configuring Tomcat users..."
cat > $TOMCAT_HOME/conf/tomcat-users.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  
  <!-- Define roles -->
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>
  
  <!-- Define users -->
  <user username="$TOMCAT_ADMIN_USER" 
        password="$TOMCAT_ADMIN_PASS" 
        roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>
  
  <!-- Additional user for deployments -->
  <user username="deployer" 
        password="Deploy2024!" 
        roles="manager-script"/>
        
</tomcat-users>
EOF

# Configure Manager app access
echo "Configuring Manager application access..."
cat > $TOMCAT_HOME/webapps/manager/META-INF/context.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!--
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.0\.0\.1|::1|0:0:0:0:0:0:0:1" />
  -->
</Context>
EOF

# Configure Host Manager app access
cat > $TOMCAT_HOME/webapps/host-manager/META-INF/context.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!--
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.0\.0\.1|::1|0:0:0:0:0:0:0:1" />
  -->
</Context>
EOF

# Configure server.xml for better performance
echo "Configuring Tomcat server settings..."
cp $TOMCAT_HOME/conf/server.xml $TOMCAT_HOME/conf/server.xml.backup

cat > $TOMCAT_HOME/conf/server.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">
    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443"
               maxThreads="200"
               minSpareThreads="10"
               enableLookups="false"
               acceptCount="100"
               compression="on"
               compressionMinSize="2048"
               compressableMimeType="text/html,text/xml,text/css,text/javascript,application/javascript,application/json" />

    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost" appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        
        <!-- Access log processes all example -->
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b %D" />
      </Host>
    </Engine>
  </Service>
</Server>
EOF

# Configure JVM options
echo "Configuring JVM options..."
cat > $TOMCAT_HOME/bin/setenv.sh << 'EOF'
#!/bin/bash

# JVM Memory settings
export CATALINA_OPTS="$CATALINA_OPTS -Xms512m"
export CATALINA_OPTS="$CATALINA_OPTS -Xmx2g"
export CATALINA_OPTS="$CATALINA_OPTS -XX:MetaspaceSize=256m"
export CATALINA_OPTS="$CATALINA_OPTS -XX:MaxMetaspaceSize=512m"

# JVM Performance settings
export CATALINA_OPTS="$CATALINA_OPTS -XX:+UseG1GC"
export CATALINA_OPTS="$CATALINA_OPTS -XX:+UseStringDeduplication"
export CATALINA_OPTS="$CATALINA_OPTS -XX:+OptimizeStringConcat"

# JVM Monitoring settings
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote"
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.port=9999"
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.rmi.port=9999"
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.ssl=false"
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
export CATALINA_OPTS="$CATALINA_OPTS -Djava.rmi.server.hostname=localhost"

# Security settings
export CATALINA_OPTS="$CATALINA_OPTS -Djava.security.egd=file:/dev/./urandom"

# Timezone
export CATALINA_OPTS="$CATALINA_OPTS -Duser.timezone=UTC"

echo "Tomcat JVM options configured: $CATALINA_OPTS"
EOF

chmod +x $TOMCAT_HOME/bin/setenv.sh

# Set proper ownership
chown -R $TOMCAT_USER: $TOMCAT_HOME

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_PID=$TOMCAT_HOME/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_HOME
Environment=CATALINA_BASE=$TOMCAT_HOME
Environment='CATALINA_OPTS=-Xms512M -Xmx2G -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=$TOMCAT_HOME/bin/startup.sh
ExecStop=$TOMCAT_HOME/bin/shutdown.sh

User=$TOMCAT_USER
Group=$TOMCAT_USER
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Tomcat service
echo "Starting Tomcat service..."
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat

# Wait for Tomcat to start
echo "Waiting for Tomcat to start..."
sleep 30

# Check Tomcat status
echo "Checking Tomcat status..."
systemctl status tomcat --no-pager

# Test Tomcat
echo "Testing Tomcat..."
for i in {1..10}; do
    if curl -s http://localhost:$TOMCAT_PORT > /dev/null; then
        echo "Tomcat is running!"
        break
    fi
    echo "Waiting for Tomcat... attempt $i"
    sleep 10
done

# Create Tomcat management script
echo "Creating Tomcat management script..."
cat > /home/ec2-user/manage-tomcat.sh << 'EOF'
#!/bin/bash

case "$1" in
  start)
    echo "Starting Tomcat..."
    sudo systemctl start tomcat
    ;;
  stop)
    echo "Stopping Tomcat..."
    sudo systemctl stop tomcat
    ;;
  restart)
    echo "Restarting Tomcat..."
    sudo systemctl restart tomcat
    ;;
  status)
    echo "Tomcat status:"
    sudo systemctl status tomcat --no-pager
    ;;
  logs)
    echo "Tomcat logs:"
    sudo journalctl -u tomcat -f
    ;;
  catalina-logs)
    echo "Catalina logs:"
    sudo tail -f /opt/tomcat/logs/catalina.out
    ;;
  access-logs)
    echo "Access logs:"
    sudo tail -f /opt/tomcat/logs/localhost_access_log.*.txt
    ;;
  deploy)
    if [ -z "$2" ]; then
      echo "Usage: $0 deploy <war-file-path>"
      exit 1
    fi
    echo "Deploying $2 to Tomcat..."
    sudo cp "$2" /opt/tomcat/webapps/
    ;;
  undeploy)
    if [ -z "$2" ]; then
      echo "Usage: $0 undeploy <app-name>"
      exit 1
    fi
    echo "Undeploying $2 from Tomcat..."
    sudo rm -rf /opt/tomcat/webapps/$2*
    ;;
  list-apps)
    echo "Deployed applications:"
    ls -la /opt/tomcat/webapps/
    ;;
  thread-dump)
    echo "Generating thread dump..."
    TOMCAT_PID=$(pgrep -f tomcat)
    sudo -u tomcat jstack $TOMCAT_PID > /tmp/tomcat-thread-dump-$(date +%Y%m%d-%H%M%S).txt
    echo "Thread dump saved to /tmp/"
    ;;
  heap-dump)
    echo "Generating heap dump..."
    TOMCAT_PID=$(pgrep -f tomcat)
    sudo -u tomcat jmap -dump:format=b,file=/tmp/tomcat-heap-dump-$(date +%Y%m%d-%H%M%S).hprof $TOMCAT_PID
    echo "Heap dump saved to /tmp/"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs|catalina-logs|access-logs|deploy|undeploy|list-apps|thread-dump|heap-dump}"
    exit 1
esac
EOF

chmod +x /home/ec2-user/manage-tomcat.sh
chown ec2-user:ec2-user /home/ec2-user/manage-tomcat.sh

# Create sample application
echo "Creating sample application..."
mkdir -p /tmp/sample-app/WEB-INF
cat > /tmp/sample-app/index.jsp << 'EOF'
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.Date" %>
<html>
<head>
    <title>Tomcat Sample Application</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { background-color: #f4f4f4; padding: 20px; border-radius: 5px; }
        .info { margin: 20px 0; padding: 15px; background-color: #e7f3ff; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Welcome to Apache Tomcat!</h1>
            <p>This is a sample JSP application running on Tomcat.</p>
        </div>
        
        <div class="info">
            <h3>Server Information:</h3>
            <p><strong>Server Time:</strong> <%= new Date() %></p>
            <p><strong>Server Info:</strong> <%= application.getServerInfo() %></p>
            <p><strong>Servlet Version:</strong> <%= application.getMajorVersion() %>.<%= application.getMinorVersion() %></p>
            <p><strong>Context Path:</strong> <%= request.getContextPath() %></p>
            <p><strong>Session ID:</strong> <%= session.getId() %></p>
        </div>
        
        <div class="info">
            <h3>System Properties:</h3>
            <p><strong>Java Version:</strong> <%= System.getProperty("java.version") %></p>
            <p><strong>Java Vendor:</strong> <%= System.getProperty("java.vendor") %></p>
            <p><strong>OS Name:</strong> <%= System.getProperty("os.name") %></p>
            <p><strong>OS Architecture:</strong> <%= System.getProperty("os.arch") %></p>
        </div>
        
        <div class="info">
            <h3>Quick Links:</h3>
            <ul>
                <li><a href="/manager/html">Tomcat Manager</a> (admin/TomcatAdmin2024!)</li>
                <li><a href="/host-manager/html">Host Manager</a></li>
                <li><a href="/docs/">Tomcat Documentation</a></li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

cat > /tmp/sample-app/WEB-INF/web.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
         http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">
    
    <display-name>Sample Tomcat Application</display-name>
    <description>A simple sample application for Tomcat</description>
    
    <welcome-file-list>
        <welcome-file>index.jsp</welcome-file>
    </welcome-file-list>
    
</web-app>
EOF

# Create WAR file and deploy
cd /tmp/sample-app
jar -cvf sample-app.war *
cp sample-app.war $TOMCAT_HOME/webapps/
chown $TOMCAT_USER: $TOMCAT_HOME/webapps/sample-app.war

# Create Tomcat information file
cat > /home/ec2-user/tomcat-info.txt << EOF
Apache Tomcat Installation Information
=====================================

Tomcat URL: http://$PUBLIC_IP:$TOMCAT_PORT
Manager URL: http://$PUBLIC_IP:$TOMCAT_PORT/manager/html
Host Manager URL: http://$PUBLIC_IP:$TOMCAT_PORT/host-manager/html
Sample App: http://$PUBLIC_IP:$TOMCAT_PORT/sample-app/

Admin Credentials:
- Username: $TOMCAT_ADMIN_USER
- Password: $TOMCAT_ADMIN_PASS

Deployment User:
- Username: deployer
- Password: Deploy2024!

Installation Details:
- Tomcat Version: $TOMCAT_VERSION
- Installation Source: $TOMCAT_TAR_FILE
- Tomcat Home: $TOMCAT_HOME
- Java Home: $JAVA_HOME
- Service User: $TOMCAT_USER
- Port: $TOMCAT_PORT

Management Commands:
- Start: ./manage-tomcat.sh start
- Stop: ./manage-tomcat.sh stop
- Restart: ./manage-tomcat.sh restart
- Status: ./manage-tomcat.sh status
- Logs: ./manage-tomcat.sh logs
- Deploy: ./manage-tomcat.sh deploy <war-file>
- Undeploy: ./manage-tomcat.sh undeploy <app-name>
- List Apps: ./manage-tomcat.sh list-apps

Configuration Files:
- Server Config: $TOMCAT_HOME/conf/server.xml
- User Config: $TOMCAT_HOME/conf/tomcat-users.xml
- JVM Config: $TOMCAT_HOME/bin/setenv.sh
- Service Config: /etc/systemd/system/tomcat.service

Log Files:
- Catalina Log: $TOMCAT_HOME/logs/catalina.out
- Access Logs: $TOMCAT_HOME/logs/localhost_access_log.*.txt
- System Logs: journalctl -u tomcat

Installation completed at: $(date)
EOF

chown ec2-user:ec2-user /home/ec2-user/tomcat-info.txt

# Setup log shipping to ELK (if available)
if command -v setup_log_shipping &> /dev/null; then
    setup_log_shipping "tomcat" \
        "/opt/tomcat/logs/catalina.out" \
        "/opt/tomcat/logs/localhost_access_log.*.txt"
fi

echo "Apache Tomcat installation completed successfully!"
echo "Access Tomcat at: http://$PUBLIC_IP:$TOMCAT_PORT"
echo "Manager App at: http://$PUBLIC_IP:$TOMCAT_PORT/manager/html"
echo "Admin credentials: $TOMCAT_ADMIN_USER / $TOMCAT_ADMIN_PASS"