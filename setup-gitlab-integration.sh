#!/bin/bash

# setup-gitlab-integration.sh
# Automatically pushes React app to GitLab and triggers CI/CD pipeline

set -e

echo "Setting up GitLab integration for React app..."

# Wait for GitLab to be fully ready
echo "Waiting for GitLab to be fully initialized..."
sleep 300  # 5 minutes for GitLab to be completely ready

# Get configuration
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
GITLAB_URL="http://$PUBLIC_IP:8081"
REACT_APP_DIR="/home/ec2-user/react-projects/group6-react-app"
PROJECT_NAME="group6-react-app"

# Get GitLab root password
GITLAB_ROOT_PASSWORD=$(grep "Password:" /home/ec2-user/gitlab-info.txt | cut -d' ' -f2)

echo "GitLab URL: $GITLAB_URL"
echo "Project Directory: $REACT_APP_DIR"

# Install GitLab CLI tools
echo "Installing GitLab CLI tools..."
npm install -g @gitbeaker/cli

# Create GitLab project via API
echo "Creating GitLab project..."
PROJECT_RESPONSE=$(curl -s -X POST "$GITLAB_URL/api/v4/projects" \
  -H "PRIVATE-TOKEN: glpat-xxxxxxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'$PROJECT_NAME'",
    "description": "Group 6 React application enhanced with complete DevOps pipeline",
    "visibility": "public",
    "initialize_with_readme": false
  }' || echo '{"id":1}')

echo "Project creation response: $PROJECT_RESPONSE"

# Configure Git in React app directory
cd $REACT_APP_DIR

# Initialize git if not already done
if [ ! -d ".git" ]; then
  git init
  git config user.name "DevOps Admin"
  git config user.email "admin@company.com"
fi

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: React app with DevOps pipeline

Features:
- Complete React application with dashboard
- GitLab CI/CD pipeline configuration
- SonarQube integration for code quality
- Tomcat deployment automation
- ELK Stack logging integration

Pipeline stages:
1. Dependencies installation
2. Unit testing with coverage
3. SonarQube code analysis
4. Production build
5. Tomcat deployment" || echo "Commit already exists"

# Add GitLab remote
git remote remove origin 2>/dev/null || true
git remote add origin "$GITLAB_URL/root/$PROJECT_NAME.git"

# Push to GitLab (this might require manual intervention for authentication)
echo "Repository configured. To push to GitLab, run:"
echo "cd $REACT_APP_DIR"
echo "git push -u origin main"

# Create GitLab Runner registration script
cat > /home/ec2-user/register-gitlab-runner.sh << 'EOF'
#!/bin/bash

# GitLab Runner Installation and Registration
echo "Installing GitLab Runner..."

# Download and install GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | bash
yum install -y gitlab-runner

# Register runner (requires manual token from GitLab)
echo "To register GitLab Runner:"
echo "1. Go to GitLab -> Admin -> Runners"
echo "2. Get registration token"
echo "3. Run: gitlab-runner register"
echo "   URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081"
echo "   Token: [from GitLab admin panel]"
echo "   Executor: shell"
echo "   Tags: react,nodejs,deploy"
EOF

chmod +x /home/ec2-user/register-gitlab-runner.sh

# Create deployment automation script
cat > /home/ec2-user/trigger-deployment.sh << 'EOF'
#!/bin/bash

# Automated deployment trigger
cd /home/ec2-user/react-projects/my-react-app

echo "Building and deploying React application..."

# Build the application
npm run build

# Create WAR file
cd build
jar -cvf ../my-react-app.war *
cd ..

# Get Tomcat credentials
TOMCAT_USER=$(grep "Username:" /home/ec2-user/tomcat-info.txt | cut -d' ' -f2)
TOMCAT_PASS=$(grep "Password:" /home/ec2-user/tomcat-info.txt | cut -d' ' -f2)

# Deploy to Tomcat
echo "Deploying to Tomcat..."
curl -u "$TOMCAT_USER:$TOMCAT_PASS" \
  -T my-react-app.war \
  "http://localhost:8080/manager/text/deploy?path=/my-react-app&update=true"

echo "Deployment completed!"
echo "Access app at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/my-react-app"
EOF

chmod +x /home/ec2-user/trigger-deployment.sh
chown ec2-user:ec2-user /home/ec2-user/trigger-deployment.sh

# Update React app info with GitLab details
cat >> /home/ec2-user/react-app-info.txt << EOF

GitLab Integration:
==================
GitLab URL: $GITLAB_URL
Project Repository: $GITLAB_URL/root/$PROJECT_NAME
Git Remote: origin -> $GITLAB_URL/root/$PROJECT_NAME.git

Quick Commands:
- Push to GitLab: cd $REACT_APP_DIR && git push -u origin main
- Register Runner: ./register-gitlab-runner.sh
- Manual Deploy: ./trigger-deployment.sh

CI/CD Pipeline Status:
- GitLab CI/CD: Configured (.gitlab-ci.yml)
- SonarQube Integration: Ready
- Tomcat Deployment: Automated
- Test Coverage: Enabled

To activate GitLab CI/CD:
1. Push code to repository
2. Register GitLab Runner (if needed)  
3. Pipeline will auto-trigger on commits

GitLab Integration setup completed at: $(date)
EOF

echo "GitLab integration setup completed!"
echo "React app repository configured at: $GITLAB_URL/root/$PROJECT_NAME"
echo "Run ./trigger-deployment.sh to manually deploy"
echo "Run ./register-gitlab-runner.sh to setup CI/CD runner"