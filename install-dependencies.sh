#!/bin/bash

# install-dependencies.sh
# Comprehensive system dependencies installation for ELK, GitLab, Tomcat, and SonarQube
# This script should be run first to prepare the system before installing any tools

set -e

LOG_FILE="/var/log/dependencies-install.log"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "localhost")

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting comprehensive dependencies installation..."

# Update system packages
log "Updating system packages..."
yum update -y

# Install basic system utilities
log "Installing basic system utilities..."
yum install -y \
    wget \
    curl \
    unzip \
    tar \
    git \
    htop \
    tree \
    nano \
    vim \
    net-tools \
    telnet \
    nc \
    jq \
    openssl \
    ca-certificates \
    yum-utils \
    device-mapper-persistent-data \
    lvm2

# Install development tools
log "Installing development tools..."
yum groupinstall -y "Development Tools"
yum install -y \
    gcc \
    gcc-c++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config

# Install Docker and Docker Compose
log "Installing Docker..."
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.21.0"
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install Java (multiple versions for compatibility)
log "Installing Java environments..."

# Java 11 (for Tomcat and general use)
yum install -y java-11-openjdk java-11-openjdk-devel

# Java 17 (for SonarQube)
yum install -y java-17-openjdk java-17-openjdk-devel

# Set Java 11 as default
alternatives --set java /usr/lib/jvm/java-11-openjdk-11.0.*/bin/java
alternatives --set javac /usr/lib/jvm/java-11-openjdk-11.0.*/bin/javac

# Install PostgreSQL 13
log "Installing PostgreSQL 13..."
yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install -y postgresql13-server postgresql13-contrib postgresql13-devel
/usr/pgsql-13/bin/postgresql-13-setup initdb
systemctl start postgresql-13
systemctl enable postgresql-13

# Configure PostgreSQL
log "Configuring PostgreSQL..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres123';"

# Update PostgreSQL configuration files
PG_VERSION="13"
PG_CONFIG_DIR="/var/lib/pgsql/${PG_VERSION}/data"

# Configure postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "${PG_CONFIG_DIR}/postgresql.conf"
sed -i "s/#port = 5432/port = 5432/" "${PG_CONFIG_DIR}/postgresql.conf"
sed -i "s/#max_connections = 100/max_connections = 200/" "${PG_CONFIG_DIR}/postgresql.conf"
sed -i "s/#shared_buffers = 128MB/shared_buffers = 256MB/" "${PG_CONFIG_DIR}/postgresql.conf"

# Configure pg_hba.conf for local connections
echo "local   all             all                                     md5" >> "${PG_CONFIG_DIR}/pg_hba.conf"
echo "host    all             all             127.0.0.1/32            md5" >> "${PG_CONFIG_DIR}/pg_hba.conf"
echo "host    all             all             ::1/128                 md5" >> "${PG_CONFIG_DIR}/pg_hba.conf"

# Restart PostgreSQL to apply changes
systemctl restart postgresql-13

# Install Node.js and npm (for GitLab and modern web tools)
log "Installing Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install Ruby (for GitLab)
log "Installing Ruby..."
yum install -y ruby ruby-devel rubygems

# Install Go (for GitLab Runner and other tools)
log "Installing Go..."
GO_VERSION="1.21.3"
wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
rm /tmp/go.tar.gz

# Install Python 3 and pip (for various automation scripts)
log "Installing Python 3..."
yum install -y python3 python3-pip python3-devel

# Install essential Python packages
pip3 install --upgrade pip
pip3 install requests pyyaml jinja2 ansible

# Install Nginx (for reverse proxy and load balancing)
log "Installing Nginx..."
amazon-linux-extras install -y nginx1
systemctl enable nginx

# Install system monitoring tools
log "Installing system monitoring tools..."
yum install -y \
    htop \
    iotop \
    sysstat \
    procps-ng \
    psmisc \
    lsof \
    strace

# Install network tools
log "Installing network tools..."
yum install -y \
    bind-utils \
    traceroute \
    mtr \
    tcpdump \
    wireshark-cli \
    nmap

# Install compression tools
log "Installing compression tools..."
yum install -y \
    gzip \
    bzip2 \
    xz \
    zip \
    unzip \
    p7zip

# Install SSL/TLS tools
log "Installing SSL/TLS tools..."
yum install -y \
    openssl \
    openssl-devel \
    certbot

# Create necessary directories
log "Creating system directories..."
mkdir -p /opt/{elk,gitlab,tomcat,sonarqube}
mkdir -p /var/log/{elk,gitlab,tomcat,sonarqube}
mkdir -p /etc/{elk,gitlab,tomcat,sonarqube}

# Set proper permissions
chown -R ec2-user:ec2-user /opt/{elk,gitlab,tomcat,sonarqube}
chown -R ec2-user:ec2-user /var/log/{elk,gitlab,tomcat,sonarqube}

# Configure firewall (if firewalld is installed)
if systemctl is-active --quiet firewalld; then
    log "Configuring firewall..."
    firewall-cmd --permanent --add-port=22/tcp    # SSH
    firewall-cmd --permanent --add-port=80/tcp    # HTTP
    firewall-cmd --permanent --add-port=443/tcp   # HTTPS
    firewall-cmd --permanent --add-port=5061/tcp  # Kibana
    firewall-cmd --permanent --add-port=9200/tcp  # Elasticsearch
    firewall-cmd --permanent --add-port=5044/tcp  # Logstash
    firewall-cmd --permanent --add-port=5050/tcp  # GitLab Registry
    firewall-cmd --permanent --add-port=8080/tcp  # Tomcat
    firewall-cmd --permanent --add-port=9000/tcp  # SonarQube
    firewall-cmd --permanent --add-port=8081/tcp  # GitLab
    firewall-cmd --permanent --add-port=5432/tcp  # PostgreSQL
    firewall-cmd --reload
fi

# Configure system limits
log "Configuring system limits..."
cat >> /etc/security/limits.conf << EOF
# ELK Stack limits
elasticsearch soft nofile 65536
elasticsearch hard nofile 65536
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited

# General limits for applications
* soft nofile 65536
* hard nofile 65536
* soft nproc 4096
* hard nproc 4096
EOF

# Configure sysctl for Elasticsearch
log "Configuring sysctl parameters..."
cat >> /etc/sysctl.conf << EOF
# Elasticsearch requirements
vm.max_map_count=262144
vm.swappiness=1
net.core.somaxconn=65535
EOF

sysctl -p

# Create service user accounts
log "Creating service user accounts..."
useradd -r -s /bin/false elasticsearch || true
useradd -r -s /bin/false logstash || true
useradd -r -s /bin/false kibana || true
useradd -r -s /bin/false gitlab || true
useradd -r -s /bin/false tomcat || true
useradd -r -s /bin/false sonarqube || true

# Install systemd service management tools
log "Installing systemd tools..."
yum install -y systemd-devel

# Setup log rotation
log "Configuring log rotation..."
cat > /etc/logrotate.d/devops-tools << EOF
/var/log/elk/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
}

/var/log/gitlab/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
}

/var/log/tomcat/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
}

/var/log/sonarqube/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
}
EOF

# Create environment file for common variables
log "Creating environment configuration..."
cat > /etc/environment << EOF
# Common environment variables for DevOps tools
JAVA_HOME=/usr/lib/jvm/java-11-openjdk
JAVA_11_HOME=/usr/lib/jvm/java-11-openjdk
JAVA_17_HOME=/usr/lib/jvm/java-17-openjdk
PATH=/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
EOF

# Source environment
source /etc/environment

# Verify installations
log "Verifying installations..."
echo "=== Installation Verification ===" | tee -a "$LOG_FILE"
echo "Docker: $(docker --version 2>/dev/null || echo 'Not installed')" | tee -a "$LOG_FILE"
echo "Docker Compose: $(docker-compose --version 2>/dev/null || echo 'Not installed')" | tee -a "$LOG_FILE"
echo "Java 11: $(java -version 2>&1 | head -1 || echo 'Not installed')" | tee -a "$LOG_FILE"
echo "Java 17: $(/usr/lib/jvm/java-17-openjdk/bin/java -version 2>&1 | head -1 || echo 'Not installed')" | tee -a "$LOG_FILE"
echo "PostgreSQL: $(sudo -u postgres psql --version 2>/dev/null || echo 'Not installed')" | tee -a "$LOG_FILE"
echo "Node.js: $(node --version 2>/dev/null || echo 'Not installed')" | tee -a "$LOG_FILE"
echo "Python3: $(python3 --version 2>/dev/null || echo 'Not installed')" | tee -a "$LOG_FILE"
echo "Go: $(/usr/local/go/bin/go version 2>/dev/null || echo 'Not installed')" | tee -a "$LOG_FILE"
echo "Nginx: $(nginx -v 2>&1 || echo 'Not installed')" | tee -a "$LOG_FILE"

# Create dependency info file
cat > /home/ec2-user/dependencies-info.txt << EOF
=== System Dependencies Installation Summary ===
Installation Date: $(date)
Server IP: $PUBLIC_IP

Installed Components:
- Docker & Docker Compose: Container runtime
- Java 11 & 17: Multi-version Java environment
- PostgreSQL 13: Database server
- Node.js 18: JavaScript runtime
- Python 3: Scripting and automation
- Go 1.21: Modern programming language
- Nginx: Web server and reverse proxy
- Development Tools: GCC, Make, etc.
- System Monitoring: htop, iotop, sysstat
- Network Tools: bind-utils, tcpdump, nmap

Configuration:
- PostgreSQL running on port 5432
- Docker service enabled
- System limits configured for ELK
- Log rotation configured
- Service users created
- Firewall ports opened (if firewalld active)

Directories Created:
- /opt/{elk,gitlab,tomcat,sonarqube}
- /var/log/{elk,gitlab,tomcat,sonarqube}
- /etc/{elk,gitlab,tomcat,sonarqube}

Next Steps:
1. Run your desired tool installation scripts
2. All dependencies are now ready
3. Check logs at: $LOG_FILE

Environment Variables:
- JAVA_HOME: /usr/lib/jvm/java-11-openjdk
- JAVA_11_HOME: /usr/lib/jvm/java-11-openjdk  
- JAVA_17_HOME: /usr/lib/jvm/java-17-openjdk
EOF

chown ec2-user:ec2-user /home/ec2-user/dependencies-info.txt

log "Dependencies installation completed successfully!"
echo "====================================="
echo "Dependencies Installation Complete!"
echo "====================================="
echo "Summary saved to: /home/ec2-user/dependencies-info.txt"
echo "Installation log: $LOG_FILE"
echo "Server IP: http://$PUBLIC_IP"
echo ""
echo "All system dependencies are now installed and configured."
echo "You can now run any of the tool installation scripts:"
echo "- ./install-elk.sh"
echo "- ./install-gitlab.sh" 
echo "- ./install-tomcat.sh"
echo "- ./install-sonarqube.sh"
echo "- ./install-tools.sh (for multiple tools)"
echo ""
echo "Reboot recommended to ensure all changes take effect:"
echo "sudo reboot"