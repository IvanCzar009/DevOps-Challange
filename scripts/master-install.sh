#!/bin/bash

# Make all scripts executable
chmod +x /opt/elk-terraform/scripts/*.sh

# Create main installation orchestrator
cat > /opt/elk-terraform/scripts/install.sh << 'EOF'
#!/bin/bash

# ELK-Terraform-Challenge101 Master Installation Script
set -e
exec > >(tee -a /var/log/elk-terraform-install.log)
exec 2>&1

echo "🚀 Starting ELK-Terraform-Challenge101 Installation..."
echo "📅 $(date)"
echo "🖥️  Instance: $(hostname)"

# Error handling function
handle_error() {
    echo "❌ Error occurred: $1"
    echo "📋 Check logs: tail -f /var/log/elk-terraform-install.log"
    exit 1
}

# Phase 1: ELK Stack Installation
echo "📊 Phase 1: Installing ELK Stack..."
/opt/elk-terraform/scripts/install-elk.sh || handle_error "ELK installation failed"

# Phase 2: Jenkins Installation
echo "🔧 Phase 2: Installing Jenkins..."
/opt/elk-terraform/scripts/install-jenkins.sh || handle_error "Jenkins installation failed"

# Phase 3: SonarQube Installation  
echo "📈 Phase 3: Installing SonarQube..."
/opt/elk-terraform/scripts/install-sonarqube.sh || handle_error "SonarQube installation failed"

# Phase 4: Tomcat Installation
echo "🚀 Phase 4: Installing Tomcat..."
/opt/elk-terraform/scripts/install-tomcat.sh || handle_error "Tomcat installation failed"

# Phase 5: Integration Setup
echo "🔗 Phase 5: Setting up integrations..."
/opt/elk-terraform/scripts/setup-integrations.sh || handle_error "Integration setup failed"

echo "🎉 Installation completed successfully!"
echo "📍 Run status check: /opt/elk-terraform/scripts/status-check.sh"
EOF

chmod +x /opt/elk-terraform/scripts/install.sh

# Run the main installation
/opt/elk-terraform/scripts/install.sh