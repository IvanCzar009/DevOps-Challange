#!/bin/bash

# Master Installation Script for DevOps Tools
# Installs ELK Stack, GitLab, Tomcat, and SonarQube

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/master-installation.log"

# Log all output
exec > >(tee $LOG_FILE) 2>&1

echo "==========================================="
echo "Master DevOps Tools Installation Script"
echo "==========================================="
echo "Starting installation at $(date)"

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Instance Public IP: $PUBLIC_IP"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS] TOOLS..."
    echo ""
    echo "TOOLS:"
    echo "  elk        Install ELK Stack (Elasticsearch, Logstash, Kibana)"
    echo "  gitlab     Install GitLab Community Edition"
    echo "  tomcat     Install Apache Tomcat 9"
    echo "  sonarqube  Install SonarQube Community Edition"
    echo "  all        Install all tools"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo "  --dry-run      Show what would be installed without installing"
    echo ""
    echo "Examples:"
    echo "  $0 elk gitlab              # Install ELK Stack and GitLab"
    echo "  $0 all                     # Install all tools"
    echo "  $0 --dry-run tomcat        # Show Tomcat installation plan"
    echo ""
}

# Function to check if script exists
check_script() {
    local tool=$1
    local script_path="$SCRIPT_DIR/install-$tool.sh"
    
    if [ ! -f "$script_path" ]; then
        echo "Error: Installation script not found: $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo "Making script executable: $script_path"
        chmod +x "$script_path"
    fi
    
    return 0
}

# Function to install a tool
install_tool() {
    local tool=$1
    local script_path="$SCRIPT_DIR/install-$tool.sh"
    
    echo ""
    echo "==========================================="
    echo "Installing $tool..."
    echo "==========================================="
    
    if check_script "$tool"; then
        echo "Running: $script_path"
        bash "$script_path"
        
        if [ $? -eq 0 ]; then
            echo "$tool installation completed successfully!"
        else
            echo "Error: $tool installation failed!"
            return 1
        fi
    else
        return 1
    fi
}

# Function to show installation plan
show_plan() {
    local tools=("$@")
    
    echo ""
    echo "==========================================="
    echo "Installation Plan"
    echo "==========================================="
    echo "The following tools will be installed:"
    
    for tool in "${tools[@]}"; do
        case $tool in
            elk)
                echo "• ELK Stack (Elasticsearch, Logstash, Kibana)"
                echo "  - Ports: 9200, 5601, 5044, 5000, 9600"
                echo "  - Services: Docker containers"
                ;;
            gitlab)
                echo "• GitLab Community Edition"
                echo "  - Ports: 80, 22 (SSH), 5050 (Registry)"
                echo "  - Services: GitLab CE with PostgreSQL"
                ;;
            tomcat)
                echo "• Apache Tomcat 9"
                echo "  - Ports: 8080, 9999 (JMX)"
                echo "  - Services: Tomcat with Java 11"
                ;;
            sonarqube)
                echo "• SonarQube Community Edition"
                echo "  - Ports: 9000"
                echo "  - Services: SonarQube with PostgreSQL"
                ;;
        esac
        echo ""
    done
    
    echo "Estimated installation time: $((${#tools[@]} * 15)) minutes"
    echo "Required disk space: ~$((${#tools[@]} * 2))GB"
    echo ""
}

# Function to create summary
create_summary() {
    local installed_tools=("$@")
    
    echo ""
    echo "==========================================="
    echo "Installation Summary"
    echo "==========================================="
    echo "Successfully installed tools:"
    
    cat > /home/ec2-user/installation-summary.txt << EOF
DevOps Tools Installation Summary
=================================
Installation Date: $(date)
Instance IP: $PUBLIC_IP

Installed Tools:
EOF

    for tool in "${installed_tools[@]}"; do
        case $tool in
            elk)
                echo "✓ ELK Stack"
                echo "  - Kibana: http://$PUBLIC_IP:5601"
                echo "  - Elasticsearch: http://$PUBLIC_IP:9200"
                echo "  - Management: ~/elk-stack/manage-elk.sh"
                echo ""
                
                cat >> /home/ec2-user/installation-summary.txt << EOF

✓ ELK Stack
  - Kibana: http://$PUBLIC_IP:5601
  - Elasticsearch: http://$PUBLIC_IP:9200
  - Logstash: $PUBLIC_IP:5044 (Beats), $PUBLIC_IP:5000 (TCP)
  - Management: ~/elk-stack/manage-elk.sh
  - Info: ~/elk-info.txt
EOF
                ;;
            gitlab)
                echo "✓ GitLab Community Edition"
                echo "  - Web Interface: http://$PUBLIC_IP"
                echo "  - Login: root / GitLab2024Admin!"
                echo "  - Management: ~/manage-gitlab.sh"
                echo ""
                
                cat >> /home/ec2-user/installation-summary.txt << EOF

✓ GitLab Community Edition
  - Web Interface: http://$PUBLIC_IP
  - Login: root / GitLab2024Admin!
  - SSH: git@$PUBLIC_IP
  - Management: ~/manage-gitlab.sh
  - Info: ~/gitlab-info.txt
EOF
                ;;
            tomcat)
                echo "✓ Apache Tomcat 9"
                echo "  - Web Interface: http://$PUBLIC_IP:8080"
                echo "  - Manager: http://$PUBLIC_IP:8080/manager/html"
                echo "  - Login: admin / TomcatAdmin2024!"
                echo "  - Management: ~/manage-tomcat.sh"
                echo ""
                
                cat >> /home/ec2-user/installation-summary.txt << EOF

✓ Apache Tomcat 9
  - Web Interface: http://$PUBLIC_IP:8080
  - Manager: http://$PUBLIC_IP:8080/manager/html
  - Login: admin / TomcatAdmin2024!
  - Sample App: http://$PUBLIC_IP:8080/sample-app/
  - Management: ~/manage-tomcat.sh
  - Info: ~/tomcat-info.txt
EOF
                ;;
            sonarqube)
                echo "✓ SonarQube Community Edition"
                echo "  - Web Interface: http://$PUBLIC_IP:9000"
                echo "  - Login: admin / admin (change after first login)"
                echo "  - Management: ~/manage-sonarqube.sh"
                echo ""
                
                cat >> /home/ec2-user/installation-summary.txt << EOF

✓ SonarQube Community Edition
  - Web Interface: http://$PUBLIC_IP:9000
  - Login: admin / admin (change after first login)
  - Scanner: /opt/sonar-scanner/bin/sonar-scanner
  - Sample Project: ~/sample-project
  - Management: ~/manage-sonarqube.sh
  - Info: ~/sonarqube-info.txt
EOF
                ;;
        esac
    done
    
    cat >> /home/ec2-user/installation-summary.txt << EOF

Management Scripts:
===================
All tools can be managed using their respective management scripts:
- ELK Stack: ~/elk-stack/manage-elk.sh {start|stop|restart|status|logs|health}
- GitLab: ~/manage-gitlab.sh {start|stop|restart|status|reconfigure|logs|backup}
- Tomcat: ~/manage-tomcat.sh {start|stop|restart|status|logs|deploy|undeploy}
- SonarQube: ~/manage-sonarqube.sh {start|stop|restart|status|logs|health|info}

Log Files:
==========
- Master Installation: $LOG_FILE
- ELK: /var/log/elk-installation.log
- GitLab: /var/log/gitlab-installation.log
- Tomcat: /var/log/tomcat-installation.log
- SonarQube: /var/log/sonarqube-installation.log

Important Notes:
================
- Change default passwords after first login
- Configure SSL/TLS certificates for production use
- Set up proper backup strategies
- Monitor system resources
- Keep software updated

Total Installation Time: $SECONDS seconds
EOF

    chown ec2-user:ec2-user /home/ec2-user/installation-summary.txt
    
    echo "Installation summary saved to: /home/ec2-user/installation-summary.txt"
}

# Parse command line arguments
VERBOSE=false
DRY_RUN=false
TOOLS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        elk|gitlab|tomcat|sonarqube)
            TOOLS+=("$1")
            shift
            ;;
        all)
            TOOLS=("elk" "gitlab" "tomcat" "sonarqube")
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if any tools were specified
if [ ${#TOOLS[@]} -eq 0 ]; then
    echo "Error: No tools specified for installation"
    usage
    exit 1
fi

# Remove duplicates
TOOLS=($(printf "%s\n" "${TOOLS[@]}" | sort -u))

# Show installation plan
show_plan "${TOOLS[@]}"

# If dry run, exit here
if [ "$DRY_RUN" = true ]; then
    echo "Dry run completed. No tools were installed."
    exit 0
fi

# Confirm installation
echo "Do you want to proceed with the installation? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Load integration helper
echo "Loading integration helper..."
source "$SCRIPT_DIR/integration-helper.sh"

# Setup integration environment
setup_integration

# Update system first
echo "Updating system packages..."
yum update -y

# Install common dependencies
echo "Installing common dependencies..."
yum install -y curl wget unzip jq nc

# Track installation time
start_time=$SECONDS

# Install each tool
INSTALLED_TOOLS=()
FAILED_TOOLS=()

for tool in "${TOOLS[@]}"; do
    echo ""
    echo "Starting $tool installation..."
    
    if install_tool "$tool"; then
        INSTALLED_TOOLS+=("$tool")
        echo "$tool installation completed successfully!"
    else
        FAILED_TOOLS+=("$tool")
        echo "$tool installation failed!"
    fi
    
    # Add delay between installations
    if [ ${#TOOLS[@]} -gt 1 ]; then
        echo "Waiting 30 seconds before next installation..."
        sleep 30
    fi
done

# Calculate total time
total_time=$((SECONDS - start_time))

echo ""
echo "==========================================="
echo "Installation Completed!"
echo "==========================================="
echo "Total time: $((total_time / 60)) minutes $((total_time % 60)) seconds"

if [ ${#INSTALLED_TOOLS[@]} -gt 0 ]; then
    echo "Successfully installed: ${INSTALLED_TOOLS[*]}"
    create_summary "${INSTALLED_TOOLS[@]}"
fi

if [ ${#FAILED_TOOLS[@]} -gt 0 ]; then
    echo "Failed installations: ${FAILED_TOOLS[*]}"
    echo "Check log files for details."
fi

echo ""
echo "All installations completed at $(date)"
echo "Summary available at: /home/ec2-user/installation-summary.txt"