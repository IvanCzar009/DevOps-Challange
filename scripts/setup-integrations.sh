#!/bin/bash

# Integration Setup Script
set -e
source /opt/elk-terraform/.env

echo "🔗 Setting up service integrations..."

# Function to wait for service
wait_for_service() {
    local service=$1
    local url=$2
    local timeout=${3:-300}
    
    echo "⏳ Waiting for $service to be ready..."
    for i in $(seq 1 $timeout); do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo "✅ $service is ready!"
            return 0
        fi
        sleep 1
    done
    echo "❌ $service not ready after ${timeout}s"
    return 1
}

echo "🔍 Verifying all services are running..."

# Verify all services are healthy
wait_for_service "Elasticsearch" "http://localhost:9200/_cluster/health"
wait_for_service "Kibana" "http://localhost:5601/api/status"
wait_for_service "Jenkins" "http://localhost:8080/login"
wait_for_service "SonarQube" "http://localhost:9000/api/system/health"
wait_for_service "Tomcat" "http://localhost:8081"

echo "✅ All services are running!"

# Configure Jenkins-SonarQube integration
echo "🔧 Configuring Jenkins-SonarQube integration..."

# Wait a bit more to ensure services are fully ready
sleep 30

# Configure SonarQube server in Jenkins
JENKINS_CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" 2>/dev/null || echo "")

if [[ -n "$JENKINS_CRUMB" ]]; then
    # Configure SonarQube server in Jenkins global configuration
    curl -X POST "http://localhost:8080/configSubmit" \
        -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "$JENKINS_CRUMB" \
        -d "name=SonarQube&serverUrl=http://host.docker.internal:9000&token=$SONARQUBE_PASSWORD" \
        2>/dev/null || echo "SonarQube server configuration attempted"
fi

# Trigger initial Jenkins build
echo "🚀 Triggering initial Jenkins build..."
sleep 10

BUILD_RESPONSE=$(curl -X POST "http://localhost:8080/job/group6-react-app-pipeline/build" \
    -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    2>/dev/null || echo "")

if [[ $? -eq 0 ]]; then
    echo "✅ Initial build triggered successfully!"
    echo "🔗 Check Jenkins: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/job/group6-react-app-pipeline/"
else
    echo "⚠️ Build trigger may have issues, but you can manually trigger it from Jenkins UI"
fi

# Set up Kibana dashboards
echo "📊 Setting up Kibana dashboards..."
sleep 20

# Create index patterns for better log visualization
curl -X POST "localhost:5601/api/saved_objects/index-pattern/services-*" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "services-*",
            "timeFieldName": "@timestamp"
        }
    }' 2>/dev/null || echo "Index pattern creation attempted"

# Create a basic dashboard
curl -X POST "localhost:5601/api/saved_objects/dashboard/elk-terraform-dashboard" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "ELK Terraform Challenge Dashboard",
            "description": "Overview of Jenkins, SonarQube, and Tomcat logs"
        }
    }' 2>/dev/null || echo "Dashboard creation attempted"

# Create log forwarding from containers to ELK
echo "📋 Setting up log forwarding..."

# Create Filebeat configuration for log collection
docker run -d \
    --name filebeat \
    --network elk-terraform_elk-network \
    --volume /var/lib/docker/containers:/var/lib/docker/containers:ro \
    --volume /var/run/docker.sock:/var/run/docker.sock:ro \
    -e ELASTICSEARCH_HOSTS=elasticsearch:9200 \
    -e LOGSTASH_HOSTS=logstash:5044 \
    docker.elastic.co/beats/filebeat:8.10.2 \
    /bin/bash -c "
        cat > /usr/share/filebeat/filebeat.yml << 'FILEBEAT_EOF'
filebeat.inputs:
- type: docker
  containers.ids:
    - '*'
  processors:
    - add_docker_metadata:
        host: unix:///var/run/docker.sock

output.logstash:
  hosts: ['logstash:5044']

logging.level: info
FILEBEAT_EOF
        filebeat -e
    " 2>/dev/null || echo "Filebeat setup attempted"

# Create restart script
echo "🔄 Creating service restart script..."
cat > /opt/elk-terraform/scripts/restart-services.sh << 'EOF'
#!/bin/bash

# Service restart script with health checks
source /opt/elk-terraform/.env

restart_service() {
    local service=$1
    local compose_file=$2
    
    echo "🔄 Restarting $service..."
    
    cd /opt/elk-terraform
    docker-compose -f $compose_file restart
    
    # Wait for service to be healthy
    sleep 30
    
    case $service in
        "elk")
            /opt/elk-terraform/scripts/health-checks.sh elk
            ;;
        "jenkins")
            /opt/elk-terraform/scripts/health-checks.sh jenkins
            ;;
        "sonarqube")
            /opt/elk-terraform/scripts/health-checks.sh sonarqube
            ;;
        "tomcat")
            /opt/elk-terraform/scripts/health-checks.sh tomcat
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        echo "✅ $service restarted successfully!"
    else
        echo "❌ $service restart failed!"
        return 1
    fi
}

case "$1" in
    elk|elasticsearch|logstash|kibana)
        restart_service "elk" "elk-compose.yml"
        ;;
    jenkins)
        restart_service "jenkins" "jenkins-compose.yml"
        ;;
    sonarqube)
        restart_service "sonarqube" "sonarqube-compose.yml"
        ;;
    tomcat)
        restart_service "tomcat" "tomcat-compose.yml"
        ;;
    all)
        restart_service "elk" "elk-compose.yml"
        restart_service "jenkins" "jenkins-compose.yml"
        restart_service "sonarqube" "sonarqube-compose.yml"
        restart_service "tomcat" "tomcat-compose.yml"
        ;;
    *)
        echo "Usage: $0 {elk|jenkins|sonarqube|tomcat|all}"
        exit 1
        ;;
esac
EOF

chmod +x /opt/elk-terraform/scripts/restart-services.sh

# Create status check script
cat > /opt/elk-terraform/scripts/status-check.sh << 'EOF'
#!/bin/bash

echo "🔍 ELK-Terraform-Challenge101 Status Check"
echo "=========================================="

get_public_ip() {
    curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost"
}

PUBLIC_IP=$(get_public_ip)

echo "📍 Server: $PUBLIC_IP"
echo ""

# Check Docker
echo "🐳 Docker Status:"
systemctl is-active docker || echo "Docker not running"
echo ""

# Check services
echo "🔍 Service Status:"
echo "├── Elasticsearch: $(curl -s http://localhost:9200/_cluster/health | jq -r '.status' 2>/dev/null || echo 'Not responding')"
echo "├── Logstash: $(nc -z localhost 5044 && echo 'Running' || echo 'Not running')"
echo "├── Kibana: $(curl -s http://localhost:5601/api/status | jq -r '.status.overall.level' 2>/dev/null || echo 'Not responding')"
echo "├── Jenkins: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/login 2>/dev/null | grep -q 200 && echo 'Running' || echo 'Not running')"
echo "├── SonarQube: $(curl -s http://localhost:9000/api/system/health | jq -r '.health' 2>/dev/null || echo 'Not responding')"
echo "└── Tomcat: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8081 2>/dev/null | grep -q 200 && echo 'Running' || echo 'Not running')"
echo ""

echo "🔗 Service URLs:"
echo "├── Jenkins:     http://$PUBLIC_IP:8080"
echo "├── SonarQube:   http://$PUBLIC_IP:9000"
echo "├── Kibana:      http://$PUBLIC_IP:5601"
echo "├── Elasticsearch: http://$PUBLIC_IP:9200"
echo "├── Tomcat:      http://$PUBLIC_IP:8081"
echo "└── React App:   http://$PUBLIC_IP:8081/group6-react-app"
echo ""

source /opt/elk-terraform/.env 2>/dev/null || true
echo "🔑 Default Credentials:"
echo "├── Jenkins:    ${JENKINS_USER:-admin}/${JENKINS_PASSWORD:-admin}"
echo "├── SonarQube:  ${SONARQUBE_USER:-admin}/${SONARQUBE_PASSWORD:-admin}"
echo "└── Tomcat:     ${TOMCAT_USERNAME:-admin}/${TOMCAT_PASSWORD:-admin}"
EOF

chmod +x /opt/elk-terraform/scripts/status-check.sh

echo "✅ Integration setup completed!"
echo ""
echo "🎉 ELK-Terraform-Challenge101 is ready!"
echo "=========================================="
echo ""
echo "📋 Quick Status Check:"
/opt/elk-terraform/scripts/status-check.sh
echo ""
echo "🚀 Next Steps:"
echo "1. Check Jenkins pipeline: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/job/group6-react-app-pipeline/"
echo "2. Monitor in Kibana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5601"
echo "3. View SonarQube analysis: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "4. Access deployed app: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081/group6-react-app"
echo ""
echo "💡 Management Commands:"
echo "- Status check: /opt/elk-terraform/scripts/status-check.sh"
echo "- Health check: /opt/elk-terraform/scripts/health-checks.sh all"
echo "- Restart services: /opt/elk-terraform/scripts/restart-services.sh all"