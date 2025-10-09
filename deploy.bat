@echo off
echo.
echo ===============================================
echo  ELK-Terraform-Challenge101 Deployment
echo ===============================================
echo.
echo 🚀 Starting one-command deployment...
echo.

REM Check if Terraform is installed
terraform version >nul 2>&1
if errorlevel 1 (
    echo ❌ Terraform is not installed or not in PATH
    echo Please install Terraform first: https://terraform.io/downloads
    pause
    exit /b 1
)

REM Check if AWS CLI is configured
aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo ❌ AWS CLI is not configured
    echo Please run: aws configure
    pause
    exit /b 1
)

REM Check if key pair exists
if not exist "Pair06.pem" (
    echo ❌ SSH key pair 'Pair06.pem' not found
    echo Please ensure your SSH key is in this directory
    pause
    exit /b 1
)

echo ✅ Prerequisites check passed
echo.
echo 📋 Deployment will create:
echo ├── AWS EC2 instance (t3.2xlarge)
echo ├── ELK Stack (Elasticsearch, Logstash, Kibana)
echo ├── Jenkins CI/CD server
echo ├── SonarQube code analysis
echo ├── Tomcat application server
echo └── Integrated monitoring and logging
echo.

set /p confirm="Continue with deployment? (y/N): "
if /i not "%confirm%"=="y" (
    echo Deployment cancelled.
    pause
    exit /b 0
)

echo.
echo 🔧 Initializing Terraform...
terraform init

if errorlevel 1 (
    echo ❌ Terraform initialization failed
    pause
    exit /b 1
)

echo.
echo 🚀 Starting deployment (this will take 20-30 minutes)...
echo.
terraform apply -auto-approve

if errorlevel 1 (
    echo ❌ Deployment failed
    echo Check the error messages above
    pause
    exit /b 1
)

echo.
echo ===============================================
echo ✅ Deployment completed successfully!
echo ===============================================
echo.
echo 📋 Your services are starting up...
echo ⏳ Please wait 5-10 minutes for full initialization
echo.
echo 💡 Next steps:
echo 1. Note the EC2 IP address from the output above
echo 2. Wait for services to fully start
echo 3. Access Jenkins to see the auto-created pipeline
echo 4. Check Kibana for log monitoring
echo 5. View SonarQube for code analysis
echo.
echo 📖 See README.md for detailed access information
echo.
pause