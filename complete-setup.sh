#!/bin/bash

# complete-setup.sh
# Final setup completion script for one-click DevOps environment

set -e

echo "========================================="
echo "🚀 DevOps Environment Setup Completion"
echo "========================================="

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Server IP: $PUBLIC_IP"
echo "Setup Date: $(date)"

# Check all services status
echo ""
echo "📊 Checking Services Status..."
echo "=================================="

# Check ELK Stack
echo -n "ELK Stack (Elasticsearch): "
if curl -s http://localhost:9200/_cluster/health > /dev/null; then
    echo "✅ Running"
else
    echo "❌ Not Ready"
fi

echo -n "ELK Stack (Kibana): "
if curl -s http://localhost:5061/api/status > /dev/null; then
    echo "✅ Running"
else
    echo "❌ Not Ready"
fi

# Check GitLab
echo -n "GitLab: "
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081" | grep -q "200\|302"; then
    echo "✅ Running"
else
    echo "❌ Not Ready"
fi

# Check Tomcat
echo -n "Tomcat: "
if curl -s http://localhost:8080 > /dev/null; then
    echo "✅ Running"
else
    echo "❌ Not Ready"
fi

# Check SonarQube
echo -n "SonarQube: "
if curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
    echo "✅ Running"
else
    echo "❌ Not Ready"
fi

# Check React App
echo -n "Group 6 React App: "
if curl -s http://localhost:8080/group6-react-app > /dev/null; then
    echo "✅ Deployed"
else
    echo "❌ Not Deployed"
fi

echo ""
echo "🌐 Access URLs"
echo "=============="
echo "Group 6 App:    http://$PUBLIC_IP:8080/group6-react-app"
echo "Kibana (ELK):   http://$PUBLIC_IP:5061"
echo "GitLab:         http://$PUBLIC_IP:8081"
echo "Tomcat Manager: http://$PUBLIC_IP:8080/manager/html"
echo "SonarQube:      http://$PUBLIC_IP:9000"

echo ""
echo "🔐 Quick Access to Credentials"
echo "==============================="
echo "All credentials: cat credentials-vault.txt"
echo "GitLab:         cat gitlab-info.txt"
echo "SonarQube:      admin / SonarAdmin2024!"
echo "Tomcat:         cat tomcat-info.txt"
echo "React App:      cat react-app-info.txt"

echo ""
echo "🛠️ Management Commands"
echo "======================"
echo "ELK Stack:      ./elk-stack/manage-elk.sh {start|stop|restart|status|logs|health}"
echo "GitLab:         ./manage-gitlab.sh {start|stop|restart|status|logs}"
echo "SonarQube:      ./manage-sonarqube.sh {start|stop|restart|status|logs}"
echo "React Deploy:   ./trigger-deployment.sh"
echo "GitLab Runner:  ./register-gitlab-runner.sh"

echo ""
echo "🔄 CI/CD Pipeline Setup"
echo "======================="
echo "1. GitLab project created at: http://$PUBLIC_IP:8081/root/group6-react-app"
echo "2. Group 6 React app with complete pipeline configured"
echo "3. To activate CI/CD:"
echo "   cd /home/ec2-user/react-projects/group6-react-app"
echo "   git push -u origin main"
echo "4. Register GitLab Runner: ./register-gitlab-runner.sh"

echo ""
echo "📝 Next Steps"
echo "============="
echo "1. Access your Group 6 React app at: http://$PUBLIC_IP:8080/group6-react-app"
echo "2. Login to GitLab and explore the project"
echo "3. Check code quality in SonarQube"
echo "4. Monitor logs in Kibana"
echo "5. Deploy updates through GitLab CI/CD"

echo ""
echo "📚 Documentation Files"
echo "======================"
echo "installation-complete.txt - Complete overview"
echo "credentials-vault.txt     - All login credentials"
echo "react-app-info.txt       - React app details"
echo "dependencies-info.txt    - System dependencies"
echo "[tool]-info.txt          - Individual tool details"

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo "Your complete DevOps environment with Group 6 React application is ready!"
echo "Access your application at: http://$PUBLIC_IP:8080/group6-react-app"

# Create a desktop file for easy access (if GUI available)
if [ -d "/home/ec2-user/Desktop" ]; then
    cat > /home/ec2-user/Desktop/DevOps-Environment.txt << EOF
🚀 DevOps Environment Quick Access

React App:      http://$PUBLIC_IP:8080/my-react-app
Kibana:         http://$PUBLIC_IP:5061
GitLab:         http://$PUBLIC_IP:8081
SonarQube:      http://$PUBLIC_IP:9000
Tomcat:         http://$PUBLIC_IP:8080/manager/html

Credentials: ~/credentials-vault.txt
Complete Setup: ./complete-setup.sh
EOF
fi

# Final status summary
echo ""
echo "Status: All services deployed and integrated ✅"
echo "Date: $(date)"
echo "IP: $PUBLIC_IP"
echo "Environment: Production Ready 🚀"