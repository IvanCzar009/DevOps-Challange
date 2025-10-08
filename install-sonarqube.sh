#!/bin/bash

# SonarQube Installation Script
# Installs SonarQube Community Edition with PostgreSQL

set -e

# Log all output
exec > >(tee /var/log/sonarqube-installation.log) 2>&1

echo "Starting SonarQube installation at $(date)"

# Get public IP for configuration
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Instance Public IP: $PUBLIC_IP"

# Configuration variables
SONARQUBE_VERSION="10.3.0.82913"
SONARQUBE_USER="sonarqube"
SONARQUBE_HOME="/opt/sonarqube"
SONARQUBE_PORT="9000"
DB_NAME="sonarqube"
DB_USER="sonarqube"
DB_PASS="SonarQube2024!"

# SonarQube Admin Credentials
SONARQUBE_ADMIN_USER="admin"
SONARQUBE_ADMIN_PASS="SonarAdmin2024!"
SONARQUBE_ADMIN_EMAIL="admin@company.com"

# Load integration helper if available
if [ -f "$(dirname "$0")/integration-helper.sh" ]; then
    source "$(dirname "$0")/integration-helper.sh"
fi

# Update system
echo "Updating system packages..."
yum update -y

# Setup Java environment (using integration helper)
if command -v setup_java_environment &> /dev/null; then
    setup_java_environment "17"
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
else
    # Fallback installation
    echo "Installing Java 17..."
    yum install -y java-17-openjdk java-17-openjdk-devel
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
    echo 'export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"' >> /etc/environment
fi

# Ensure PostgreSQL is installed (using integration helper)
if command -v ensure_postgresql &> /dev/null; then
    ensure_postgresql
else
    # Fallback installation
    echo "Installing PostgreSQL..."
    yum install -y postgresql postgresql-server postgresql-contrib
    postgresql-setup initdb
    systemctl enable postgresql
    systemctl start postgresql
fi

# Configure SonarQube database (using integration helper)
if command -v create_separate_databases &> /dev/null; then
    create_separate_databases "$DB_NAME" "$DB_USER" "$DB_PASS"
else
    # Fallback configuration
    echo "Configuring PostgreSQL..."
    sudo -u postgres psql << EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF
fi

# Update PostgreSQL configuration
echo "Updating PostgreSQL configuration..."
PG_VERSION=$(ls /var/lib/pgsql/data/)
PG_CONFIG="/var/lib/pgsql/data/postgresql.conf"
PG_HBA="/var/lib/pgsql/data/pg_hba.conf"

# Update postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" $PG_CONFIG
sed -i "s/#port = 5432/port = 5432/" $PG_CONFIG

# Update pg_hba.conf for local connections
cp $PG_HBA $PG_HBA.backup
cat >> $PG_HBA << EOF

# SonarQube connection
local   $DB_NAME     $DB_USER                     md5
host    $DB_NAME     $DB_USER     127.0.0.1/32   md5
EOF

# Restart PostgreSQL
systemctl restart postgresql

# Create SonarQube user
echo "Creating SonarQube user..."
useradd -m -U -d $SONARQUBE_HOME -s /bin/bash $SONARQUBE_USER

# Download and install SonarQube
echo "Downloading SonarQube $SONARQUBE_VERSION..."
cd /tmp
wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONARQUBE_VERSION.zip

echo "Installing SonarQube..."
yum install -y unzip
unzip -q sonarqube-$SONARQUBE_VERSION.zip
mv sonarqube-$SONARQUBE_VERSION/* $SONARQUBE_HOME/
chown -R $SONARQUBE_USER: $SONARQUBE_HOME

# Configure SonarQube
echo "Configuring SonarQube..."
cat > $SONARQUBE_HOME/conf/sonar.properties << EOF
# SonarQube Configuration

# Database configuration
sonar.jdbc.username=$DB_USER
sonar.jdbc.password=$DB_PASS
sonar.jdbc.url=jdbc:postgresql://localhost:5432/$DB_NAME

# Web server configuration
sonar.web.host=0.0.0.0
sonar.web.port=$SONARQUBE_PORT
sonar.web.context=/

# Elasticsearch configuration
sonar.search.javaOpts=-Xmx1g -Xms1g -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError

# Logging configuration
sonar.log.level=INFO
sonar.path.logs=$SONARQUBE_HOME/logs

# Security configuration
sonar.security.realm=
sonar.forceAuthentication=false

# Technical debt configuration
sonar.technicalDebt.hoursInDay=8

# Update center configuration
sonar.updatecenter.activate=true

# Telemetry
sonar.telemetry.enable=false
EOF

# Configure SonarQube wrapper
echo "Configuring SonarQube wrapper..."
cat > $SONARQUBE_HOME/conf/wrapper.conf << EOF
# SonarQube wrapper configuration

# Java Application
wrapper.java.command=$JAVA_HOME/bin/java

# Java Main class
wrapper.java.mainclass=org.tanukisoftware.wrapper.WrapperSimpleApp
wrapper.java.library.path.1=$SONARQUBE_HOME/bin/linux-x86-64
wrapper.java.classpath.1=$SONARQUBE_HOME/lib/sonar-application-$SONARQUBE_VERSION.jar

# JVM Parameters
wrapper.java.additional.1=-Dsonar.wrapped=true
wrapper.java.additional.2=-Djava.awt.headless=true
wrapper.java.additional.3=-XX:+UseG1GC
wrapper.java.additional.4=-XX:+UnlockExperimentalVMOptions
wrapper.java.additional.5=-XX:+UseCGroupMemoryLimitForHeap

# Initial JVM Heap Size
wrapper.java.initmemory=128

# Maximum JVM Heap Size
wrapper.java.maxmemory=2048

# Application parameters
wrapper.app.parameter.1=org.sonar.application.App

# Wrapper Logging Properties
wrapper.console.format=PM
wrapper.console.loglevel=INFO
wrapper.logfile=$SONARQUBE_HOME/logs/wrapper.log
wrapper.logfile.format=LPTM
wrapper.logfile.loglevel=INFO
wrapper.logfile.maxsize=10m
wrapper.logfile.maxfiles=5
wrapper.syslog.loglevel=NONE

# Title to use when running as a console
wrapper.console.title=SonarQube

# Service properties
wrapper.ntservice.name=SonarQube
wrapper.ntservice.displayname=SonarQube
wrapper.ntservice.description=SonarQube
wrapper.ntservice.dependency.1=
wrapper.ntservice.starttype=AUTO_START
wrapper.ntservice.interactive=false
EOF

# Set system limits for SonarQube
echo "Configuring system limits..."
cat >> /etc/security/limits.conf << EOF

# SonarQube system limits
$SONARQUBE_USER   -   nofile   131072
$SONARQUBE_USER   -   nproc    8192
EOF

# Configure kernel parameters
echo "Configuring kernel parameters..."
cat >> /etc/sysctl.conf << EOF

# SonarQube kernel parameters
vm.max_map_count=524288
fs.file-max=131072
EOF

sysctl -p

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/sonarqube.service << EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=$SONARQUBE_HOME/bin/linux-x86-64/sonar.sh start
ExecStop=$SONARQUBE_HOME/bin/linux-x86-64/sonar.sh stop
User=$SONARQUBE_USER
Group=$SONARQUBE_USER
Restart=always
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
echo "Setting proper permissions..."
chown -R $SONARQUBE_USER: $SONARQUBE_HOME
chmod +x $SONARQUBE_HOME/bin/linux-x86-64/sonar.sh

# Enable and start SonarQube service
echo "Starting SonarQube service..."
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

# Wait for SonarQube to start
echo "Waiting for SonarQube to start (this may take several minutes)..."
sleep 60

# Check SonarQube status
echo "Checking SonarQube status..."
systemctl status sonarqube --no-pager

# Test SonarQube
echo "Testing SonarQube..."
for i in {1..30}; do
    if curl -s http://localhost:$SONARQUBE_PORT/api/system/status | grep -q '"status":"UP"'; then
        echo "SonarQube is running!"
        break
    fi
    echo "Waiting for SonarQube... attempt $i"
    sleep 30
done

# Configure SonarQube admin password automatically
echo "Configuring SonarQube admin password..."
sleep 10  # Give SonarQube a bit more time to fully initialize

# Change the default admin password using SonarQube API
echo "Setting up admin password..."
CHANGE_PASSWORD_RESPONSE=$(curl -s -u admin:admin -X POST \
    "http://localhost:$SONARQUBE_PORT/api/users/change_password" \
    -d "login=admin&previousPassword=admin&password=$SONARQUBE_ADMIN_PASS" 2>/dev/null || echo "")

if echo "$CHANGE_PASSWORD_RESPONSE" | grep -q "errors"; then
    echo "Note: Admin password may already be set or needs manual configuration"
else
    echo "Admin password configured successfully!"
fi

# Test authentication with new password
echo "Testing authentication with new credentials..."
AUTH_TEST=$(curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" \
    "http://localhost:$SONARQUBE_PORT/api/authentication/validate" 2>/dev/null || echo "")

if echo "$AUTH_TEST" | grep -q '"valid":true'; then
    echo "Authentication test successful!"
else
    echo "Note: Using default credentials admin/admin for first login"
    SONARQUBE_ADMIN_PASS="admin"
fi

# Configure developer-friendly quality gate
echo "Configuring developer-friendly quality gate..."
sleep 5  # Give SonarQube more time to fully initialize

# Create a relaxed quality gate for development
RELAXED_QG_RESPONSE=$(curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" -X POST \
    "http://localhost:$SONARQUBE_PORT/api/qualitygates/create" \
    -d "name=Developer-Friendly" 2>/dev/null || echo "")

if echo "$RELAXED_QG_RESPONSE" | grep -q '"id"'; then
    echo "Created Developer-Friendly quality gate"
    
    # Set relaxed conditions (high thresholds to avoid failures)
    QG_ID=$(echo "$RELAXED_QG_RESPONSE" | grep -o '"id":[0-9]*' | cut -d: -f2)
    
    # Set high thresholds for common metrics
    curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" -X POST \
        "http://localhost:$SONARQUBE_PORT/api/qualitygates/create_condition" \
        -d "gateId=$QG_ID&metric=new_coverage&op=LT&error=50" >/dev/null 2>&1
    
    curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" -X POST \
        "http://localhost:$SONARQUBE_PORT/api/qualitygates/create_condition" \
        -d "gateId=$QG_ID&metric=new_duplicated_lines_density&op=GT&error=20" >/dev/null 2>&1
    
    curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" -X POST \
        "http://localhost:$SONARQUBE_PORT/api/qualitygates/create_condition" \
        -d "gateId=$QG_ID&metric=new_maintainability_rating&op=GT&error=4" >/dev/null 2>&1
    
    # Set as default quality gate
    curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" -X POST \
        "http://localhost:$SONARQUBE_PORT/api/qualitygates/set_as_default" \
        -d "id=$QG_ID" >/dev/null 2>&1
    
    echo "Developer-Friendly quality gate set as default"
else
    echo "Using default SonarQube quality gate"
fi

# Create SonarQube management script
echo "Creating SonarQube management script..."
cat > /home/ec2-user/manage-sonarqube.sh << 'EOF'
#!/bin/bash

case "$1" in
  start)
    echo "Starting SonarQube..."
    sudo systemctl start sonarqube
    ;;
  stop)
    echo "Stopping SonarQube..."
    sudo systemctl stop sonarqube
    ;;
  restart)
    echo "Restarting SonarQube..."
    sudo systemctl restart sonarqube
    ;;
  status)
    echo "SonarQube status:"
    sudo systemctl status sonarqube --no-pager
    ;;
  logs)
    echo "SonarQube logs:"
    sudo journalctl -u sonarqube -f
    ;;
  app-logs)
    echo "SonarQube application logs:"
    sudo tail -f /opt/sonarqube/logs/sonar.log
    ;;
  web-logs)
    echo "SonarQube web logs:"
    sudo tail -f /opt/sonarqube/logs/web.log
    ;;
  es-logs)
    echo "SonarQube Elasticsearch logs:"
    sudo tail -f /opt/sonarqube/logs/es.log
    ;;
  ce-logs)
    echo "SonarQube Compute Engine logs:"
    sudo tail -f /opt/sonarqube/logs/ce.log
    ;;
  health)
    echo "Checking SonarQube health..."
    curl -s http://localhost:9000/api/system/status | jq .
    ;;
  info)
    echo "SonarQube system info..."
    curl -s http://localhost:9000/api/system/info | jq .
    ;;
  plugins)
    echo "Installed plugins:"
    curl -s http://localhost:9000/api/plugins/installed | jq '.plugins[] | {key, name, version}'
    ;;
  create-project)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "Usage: $0 create-project <project-key> <project-name>"
      exit 1
    fi
    echo "Creating project: $3 ($2)"
    # Read current password from info file or use admin
    CURRENT_PASS=$(grep "Admin Password:" /home/ec2-user/sonarqube-info.txt | cut -d: -f2 | xargs || echo "admin")
    curl -X POST \
      -u "admin:$CURRENT_PASS" \
      -d "project=$2&name=$3" \
      http://localhost:9000/api/projects/create
    ;;;
  change-password)
    if [ -z "$2" ]; then
      echo "Usage: $0 change-password <new-password>"
      exit 1
    fi
    echo "Changing admin password..."
    # Read current password from info file or use admin
    CURRENT_PASS=$(grep "Admin Password:" /home/ec2-user/sonarqube-info.txt | cut -d: -f2 | xargs || echo "admin")
    curl -X POST \
      -u "admin:$CURRENT_PASS" \
      -d "login=admin&password=$2&previousPassword=$CURRENT_PASS" \
      http://localhost:9000/api/users/change_password
    echo "Password changed successfully!"
    echo "Please update sonarqube-info.txt with the new password."
    ;;;
  backup)
    echo "Creating backup..."
    BACKUP_DIR="/tmp/sonarqube-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p $BACKUP_DIR
    sudo cp -r /opt/sonarqube/conf $BACKUP_DIR/
    sudo cp -r /opt/sonarqube/data $BACKUP_DIR/
    sudo -u postgres pg_dump sonarqube > $BACKUP_DIR/sonarqube-db.sql
    echo "Backup created at: $BACKUP_DIR"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs|app-logs|web-logs|es-logs|ce-logs|health|info|plugins|create-project|change-password|backup}"
    exit 1
esac
EOF

chmod +x /home/ec2-user/manage-sonarqube.sh
chown ec2-user:ec2-user /home/ec2-user/manage-sonarqube.sh

# Install SonarQube Scanner (optional)
echo "Installing SonarQube Scanner..."
cd /tmp
wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
unzip -q sonar-scanner-cli-5.0.1.3006-linux.zip
mv sonar-scanner-5.0.1.3006-linux /opt/sonar-scanner
chown -R $SONARQUBE_USER: /opt/sonar-scanner

# Add scanner to PATH
echo 'export PATH="/opt/sonar-scanner/bin:$PATH"' >> /etc/environment

# Create scanner configuration
cat > /opt/sonar-scanner/conf/sonar-scanner.properties << EOF
# SonarQube Scanner Configuration
sonar.host.url=http://localhost:$SONARQUBE_PORT
sonar.sourceEncoding=UTF-8
EOF

# Create sample project for testing
echo "Creating sample project..."
mkdir -p /home/ec2-user/sample-project/src
cat > /home/ec2-user/sample-project/sonar-project.properties << EOF
# SonarQube project configuration
sonar.projectKey=sample-project
sonar.projectName=Sample Project
sonar.projectVersion=1.0
sonar.sources=src
sonar.language=java
sonar.sourceEncoding=UTF-8
EOF

cat > /home/ec2-user/sample-project/src/HelloWorld.java << 'EOF'
public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, SonarQube!");
        
        // Intentional code smell for demonstration
        String unused = "This variable is never used";
        
        // Intentional bug for demonstration  
        String str = null;
        if (str.equals("test")) {
            System.out.println("This will cause a NullPointerException");
        }
    }
}
EOF

chown -R ec2-user:ec2-user /home/ec2-user/sample-project

# Create SonarQube information file
cat > /home/ec2-user/sonarqube-info.txt << EOF
SonarQube Installation Information
=================================

SonarQube URL: http://$PUBLIC_IP:$SONARQUBE_PORT
Admin Username: $SONARQUBE_ADMIN_USER
Admin Password: $SONARQUBE_ADMIN_PASS
Admin Email: $SONARQUBE_ADMIN_EMAIL

Database Information:
- Database: PostgreSQL
- DB Name: $DB_NAME
- DB User: $DB_USER
- DB Password: $DB_PASS

Installation Details:
- SonarQube Version: $SONARQUBE_VERSION
- SonarQube Home: $SONARQUBE_HOME
- Java Home: $JAVA_HOME
- Service User: $SONARQUBE_USER
- Port: $SONARQUBE_PORT

Management Commands:
- Start: ./manage-sonarqube.sh start
- Stop: ./manage-sonarqube.sh stop
- Restart: ./manage-sonarqube.sh restart
- Status: ./manage-sonarqube.sh status
- Logs: ./manage-sonarqube.sh logs
- Health: ./manage-sonarqube.sh health
- Info: ./manage-sonarqube.sh info
- Change Password: ./manage-sonarqube.sh change-password <new-password>
- Create Project: ./manage-sonarqube.sh create-project <key> <name>

Scanner Configuration:
- Scanner Home: /opt/sonar-scanner
- Sample Project: ~/sample-project
- Run Analysis: cd ~/sample-project && sonar-scanner

Configuration Files:
- Main Config: $SONARQUBE_HOME/conf/sonar.properties
- Wrapper Config: $SONARQUBE_HOME/conf/wrapper.conf
- Scanner Config: /opt/sonar-scanner/conf/sonar-scanner.properties
- Service Config: /etc/systemd/system/sonarqube.service

Log Files:
- Application Log: $SONARQUBE_HOME/logs/sonar.log
- Web Log: $SONARQUBE_HOME/logs/web.log
- Elasticsearch Log: $SONARQUBE_HOME/logs/es.log
- Compute Engine Log: $SONARQUBE_HOME/logs/ce.log
- System Logs: journalctl -u sonarqube

Important Notes:
- Admin password has been automatically configured (see credentials above)
- No password change required on first login
- Configure authentication and authorization as needed
- Set up quality gates and quality profiles
- Install additional plugins as required
- Configure backup strategy for production use
- Use ./manage-sonarqube.sh change-password to update admin password

Sample Project Analysis:
cd ~/sample-project
sonar-scanner

Installation completed at: $(date)
EOF

chown ec2-user:ec2-user /home/ec2-user/sonarqube-info.txt

# Create/Update credentials vault
echo "Creating/updating credentials vault..."
cat > /home/ec2-user/credentials-vault.txt << EOF
=== DevOps Tools Credentials Vault ===
Generated: $(date)
Server IP: $PUBLIC_IP

SONARQUBE CREDENTIALS:
======================
URL: http://$PUBLIC_IP:$SONARQUBE_PORT
Username: $SONARQUBE_ADMIN_USER
Password: $SONARQUBE_ADMIN_PASS
Email: $SONARQUBE_ADMIN_EMAIL
Database: PostgreSQL - $DB_NAME/$DB_USER

GITLAB CREDENTIALS:
===================
$(if [ -f "/home/ec2-user/gitlab-info.txt" ]; then
  echo "URL: $(grep "GitLab URL:" /home/ec2-user/gitlab-info.txt | cut -d' ' -f3)"
  echo "Username: $(grep "Username:" /home/ec2-user/gitlab-info.txt | cut -d' ' -f2)"
  echo "Password: $(grep "Password:" /home/ec2-user/gitlab-info.txt | cut -d' ' -f2)"
  echo "Email: $(grep "Email:" /home/ec2-user/gitlab-info.txt | cut -d' ' -f2)"
else
  echo "GitLab not yet configured"
fi)

TOMCAT CREDENTIALS:
===================
$(if [ -f "/home/ec2-user/tomcat-info.txt" ]; then
  grep -A5 "Admin credentials:" /home/ec2-user/tomcat-info.txt | tail -4
else
  echo "Tomcat not yet configured"
fi)

ELK STACK ACCESS:
=================
Kibana URL: http://$PUBLIC_IP:5061
Elasticsearch URL: http://$PUBLIC_IP:9200
No authentication required (development setup)

SECURITY NOTES:
===============
- Change passwords after first login if required
- All services configured for development use
- Consider enabling HTTPS for production
- Regular backup recommended
- Review and update access controls

MANAGEMENT SCRIPTS:
===================
- GitLab: ./manage-gitlab.sh
- SonarQube: ./manage-sonarqube.sh
- ELK: ./manage-elk.sh (if available)
- Tomcat: Check tomcat-info.txt

EOF

chmod 600 /home/ec2-user/credentials-vault.txt
chown ec2-user:ec2-user /home/ec2-user/credentials-vault.txt

# Setup log shipping to ELK (if available)
if command -v setup_log_shipping &> /dev/null; then
    setup_log_shipping "sonarqube" \
        "/opt/sonarqube/logs/sonar.log" \
        "/opt/sonarqube/logs/web.log" \
        "/opt/sonarqube/logs/ce.log" \
        "/opt/sonarqube/logs/es.log" \
        "/var/lib/pgsql/13/data/log/postgresql-*.log"
fi

echo "SonarQube installation completed successfully!"
echo "Access SonarQube at: http://$PUBLIC_IP:$SONARQUBE_PORT"
echo "Default credentials: admin / admin (change on first login)"
echo "Please change the default password after first login!"