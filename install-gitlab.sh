#!/bin/bash

# GitLab Installation Script
# Installs GitLab Community Edition

set -e

# Log all output
exec > >(tee /var/log/gitlab-installation.log) 2>&1

echo "Starting GitLab installation at $(date)"

# Get public IP for configuration
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Instance Public IP: $PUBLIC_IP"

# Configuration variables
GITLAB_EXTERNAL_URL="http://$PUBLIC_IP:8081"
GITLAB_ROOT_PASSWORD="GitLab2024Admin!"
GITLAB_ROOT_EMAIL="admin@$PUBLIC_IP.nip.io"

echo "GitLab will be configured with URL: $GITLAB_EXTERNAL_URL"

# Load integration helper if available
if [ -f "$(dirname "$0")/integration-helper.sh" ]; then
    source "$(dirname "$0")/integration-helper.sh"
fi

# Update system
echo "Updating system packages..."
yum update -y

# Install required dependencies
echo "Installing dependencies..."
yum install -y curl policycoreutils openssh-server openssh-clients postfix

# Start and enable services
echo "Starting and enabling services..."
systemctl enable sshd
systemctl start sshd
systemctl enable postfix
systemctl start postfix

# Configure firewall (if firewalld is running)
if systemctl is-active --quiet firewalld; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
fi

# Add GitLab repository
echo "Adding GitLab repository..."
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash

# Install GitLab CE
echo "Installing GitLab Community Edition..."
EXTERNAL_URL="$GITLAB_EXTERNAL_URL" yum install -y gitlab-ce

# Create GitLab configuration
echo "Creating GitLab configuration..."
cat > /etc/gitlab/gitlab.rb << EOF
# GitLab configuration file
external_url '$GITLAB_EXTERNAL_URL'

# GitLab Rails configuration
gitlab_rails['gitlab_email_enabled'] = true
gitlab_rails['gitlab_email_from'] = '$GITLAB_ROOT_EMAIL'
gitlab_rails['gitlab_email_display_name'] = 'GitLab Administrator'
gitlab_rails['initial_root_password'] = '$GITLAB_ROOT_PASSWORD'

# Disable Let's Encrypt for now
letsencrypt['enable'] = false

# Nginx configuration
nginx['listen_port'] = 80
nginx['listen_https'] = false

# Memory optimization for shared instance
postgresql['shared_buffers'] = "256MB"
postgresql['max_connections'] = 200
sidekiq['concurrency'] = 10
unicorn['worker_processes'] = 3
unicorn['worker_memory_limit_min'] = "200 * 1 << 20"
unicorn['worker_memory_limit_max'] = "300 * 1 << 20"

# GitLab Shell configuration
gitlab_shell['ssh_port'] = 22

# Backup configuration
gitlab_rails['backup_keep_time'] = 604800  # 7 days

# SMTP configuration (using local postfix)
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "localhost"
gitlab_rails['smtp_port'] = 25
gitlab_rails['smtp_domain'] = "$PUBLIC_IP.nip.io"
gitlab_rails['smtp_tls'] = false

# Time zone
gitlab_rails['time_zone'] = 'UTC'

# Session configuration
gitlab_rails['session_expire_delay'] = 10080  # 7 days

# Registry configuration (disabled by default)
registry['enable'] = false

# Pages configuration (disabled by default)
gitlab_pages['enable'] = false

# Mattermost configuration (disabled by default)
mattermost['enable'] = false

# Monitoring configuration
prometheus_monitoring['enable'] = true
alertmanager['enable'] = false
grafana['enable'] = false
EOF

echo "GitLab configuration created successfully"

# Reconfigure GitLab
echo "Reconfiguring GitLab (this may take several minutes)..."
gitlab-ctl reconfigure

# Start GitLab services
echo "Starting GitLab services..."
gitlab-ctl start

# Wait for GitLab to be ready
echo "Waiting for GitLab to be ready..."
sleep 120

# Check GitLab status
echo "Checking GitLab status..."
gitlab-ctl status

# Test GitLab readiness
echo "Testing GitLab readiness..."
for i in {1..20}; do
    if curl -s -o /dev/null -w "%{http_code}" "$GITLAB_EXTERNAL_URL" | grep -q "200\|302"; then
        echo "GitLab is ready!"
        break
    fi
    echo "Waiting for GitLab... attempt $i"
    sleep 30
done

# Create GitLab management script
echo "Creating GitLab management script..."
cat > /home/ec2-user/manage-gitlab.sh << 'EOF'
#!/bin/bash

case "$1" in
  start)
    echo "Starting GitLab..."
    sudo gitlab-ctl start
    ;;
  stop)
    echo "Stopping GitLab..."
    sudo gitlab-ctl stop
    ;;
  restart)
    echo "Restarting GitLab..."
    sudo gitlab-ctl restart
    ;;
  status)
    echo "GitLab status:"
    sudo gitlab-ctl status
    ;;
  reconfigure)
    echo "Reconfiguring GitLab..."
    sudo gitlab-ctl reconfigure
    ;;
  logs)
    echo "GitLab logs:"
    sudo gitlab-ctl tail
    ;;
  backup)
    echo "Creating GitLab backup..."
    sudo gitlab-backup create
    ;;
  console)
    echo "Opening GitLab Rails console..."
    sudo gitlab-rails console
    ;;
  check)
    echo "Running GitLab health check..."
    sudo gitlab-rake gitlab:check
    ;;
  update)
    echo "Updating GitLab..."
    sudo yum update gitlab-ce
    sudo gitlab-ctl reconfigure
    ;;
  reset-password)
    echo "Reset root password in GitLab Rails console:"
    echo "user = User.find_by(username: 'root')"
    echo "user.password = 'NewPassword123!'"
    echo "user.password_confirmation = 'NewPassword123!'"
    echo "user.save!"
    sudo gitlab-rails console
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|reconfigure|logs|backup|console|check|update|reset-password}"
    exit 1
esac
EOF

chmod +x /home/ec2-user/manage-gitlab.sh
chown ec2-user:ec2-user /home/ec2-user/manage-gitlab.sh

# Enable GitLab to start on boot
echo "Enabling GitLab to start on boot..."
systemctl enable gitlab-runsvdir

# Create GitLab access information file
echo "Creating GitLab access information..."
cat > /home/ec2-user/gitlab-info.txt << EOF
GitLab Installation Information
===============================

GitLab URL: $GITLAB_EXTERNAL_URL
Username: root
Password: $GITLAB_ROOT_PASSWORD
Email: $GITLAB_ROOT_EMAIL

Management Commands:
- Start: ./manage-gitlab.sh start
- Stop: ./manage-gitlab.sh stop
- Restart: ./manage-gitlab.sh restart
- Status: ./manage-gitlab.sh status
- Reconfigure: ./manage-gitlab.sh reconfigure
- Logs: ./manage-gitlab.sh logs
- Backup: ./manage-gitlab.sh backup
- Health Check: ./manage-gitlab.sh check
- Reset Password: ./manage-gitlab.sh reset-password

Important Notes:
- Please change the root password after first login
- GitLab is configured to use HTTP (not HTTPS)
- Backups are kept for 7 days
- SSH port is 22 for Git operations

Configuration File: /etc/gitlab/gitlab.rb
Log Files: /var/log/gitlab/
Data Directory: /var/opt/gitlab/

Installation completed at: $(date)
EOF

chown ec2-user:ec2-user /home/ec2-user/gitlab-info.txt

# Setup log shipping to ELK (if available)
if command -v setup_log_shipping &> /dev/null; then
    setup_log_shipping "gitlab" \
        "/var/log/gitlab/gitlab-rails/production.log" \
        "/var/log/gitlab/gitlab-rails/application.log" \
        "/var/log/gitlab/nginx/gitlab_access.log" \
        "/var/log/gitlab/nginx/gitlab_error.log" \
        "/var/log/gitlab/postgresql/postgresql.log" \
        "/var/log/gitlab/sidekiq/current"
fi

# Final status check
echo "Final GitLab status check..."
gitlab-ctl status > /var/log/gitlab-final-status.log

# Update credentials vault
echo "Updating credentials vault..."
if [ -f "/home/ec2-user/credentials-vault.txt" ]; then
    # Update existing vault
    sed -i "/GITLAB CREDENTIALS:/,/TOMCAT CREDENTIALS:/{
        /GITLAB CREDENTIALS:/!{/TOMCAT CREDENTIALS:/!d;}
    }" /home/ec2-user/credentials-vault.txt
    
    # Insert updated GitLab credentials
    sed -i "/GITLAB CREDENTIALS:/a\\
URL: $GITLAB_EXTERNAL_URL\\
Username: root\\
Password: $GITLAB_ROOT_PASSWORD\\
Email: $GITLAB_ROOT_EMAIL\\
\\
" /home/ec2-user/credentials-vault.txt
else
    # Create initial vault if it doesn't exist
    cat > /home/ec2-user/credentials-vault.txt << EOF
=== DevOps Tools Credentials Vault ===
Generated: $(date)
Server IP: $PUBLIC_IP

GITLAB CREDENTIALS:
===================
URL: $GITLAB_EXTERNAL_URL
Username: root
Password: $GITLAB_ROOT_PASSWORD
Email: $GITLAB_ROOT_EMAIL

EOF
    chmod 600 /home/ec2-user/credentials-vault.txt
    chown ec2-user:ec2-user /home/ec2-user/credentials-vault.txt
fi

echo "GitLab installation completed at $(date)!" | tee -a /var/log/gitlab-installation.log
echo "GitLab URL: $GITLAB_EXTERNAL_URL" | tee -a /var/log/gitlab-installation.log
echo "Root username: root" | tee -a /var/log/gitlab-installation.log
echo "Root password: $GITLAB_ROOT_PASSWORD" | tee -a /var/log/gitlab-installation.log
echo "Please change the root password after first login!" | tee -a /var/log/gitlab-installation.log

echo "GitLab installation completed successfully!"
echo "Access GitLab at: $GITLAB_EXTERNAL_URL"