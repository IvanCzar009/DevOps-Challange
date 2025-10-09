#!/bin/bash

# ELK Stack Installation Script
set -e
source /opt/elk-terraform/.env

echo "📊 Installing ELK Stack (Elasticsearch, Logstash, Kibana)..."

# Create ELK configuration directory
mkdir -p /opt/elk-terraform/config/elk

# Create Elasticsearch configuration
cat > /opt/elk-terraform/config/elk/elasticsearch.yml << 'EOF'
cluster.name: "elk-terraform-cluster"
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
EOF

# Create Logstash configuration
cat > /opt/elk-terraform/config/elk/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
  file {
    path => "/var/log/jenkins/jenkins.log"
    start_position => "beginning"
    type => "jenkins"
  }
  file {
    path => "/opt/sonarqube/logs/sonar.log"
    start_position => "beginning"
    type => "sonarqube"
  }
  file {
    path => "/opt/tomcat/logs/catalina.out"
    start_position => "beginning"
    type => "tomcat"
  }
}

filter {
  if [type] == "jenkins" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" }
    }
  }
  if [type] == "sonarqube" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{WORD:level} %{GREEDYDATA:message}" }
    }
  }
  if [type] == "tomcat" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "%{type}-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

# Create Kibana configuration
cat > /opt/elk-terraform/config/elk/kibana.yml << 'EOF'
server.host: "0.0.0.0"
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
server.name: "kibana-elk-terraform"
EOF

# Create ELK Docker Compose file
cat > /opt/elk-terraform/elk-compose.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.2
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
      - /opt/elk-terraform/config/elk/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml
    ports:
      - "9200:9200"
    networks:
      - elk-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  logstash:
    image: docker.elastic.co/logstash/logstash:8.10.2
    container_name: logstash
    volumes:
      - /opt/elk-terraform/config/elk/logstash.conf:/usr/share/logstash/pipeline/logstash.conf
      - /var/log:/var/log:ro
    ports:
      - "5044:5044"
    networks:
      - elk-network
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "nc -z localhost 5044 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  kibana:
    image: docker.elastic.co/kibana/kibana:8.10.2
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    volumes:
      - /opt/elk-terraform/config/elk/kibana.yml:/usr/share/kibana/config/kibana.yml
    ports:
      - "5601:5601"
    networks:
      - elk-network
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  elasticsearch_data:
    driver: local

networks:
  elk-network:
    driver: bridge
EOF

echo "🚀 Starting ELK Stack..."
cd /opt/elk-terraform
docker-compose -f elk-compose.yml up -d

echo "⏳ Waiting for ELK Stack to be ready..."
sleep 30

# Health check
if /opt/elk-terraform/scripts/health-checks.sh elk; then
    echo "✅ ELK Stack installation completed successfully!"
    
    # Create default Kibana index patterns
    echo "📋 Setting up Kibana index patterns..."
    sleep 60  # Wait for Kibana to be fully ready
    
    # Create index patterns for each service
    curl -X POST "localhost:5601/api/saved_objects/index-pattern/jenkins-*" \
      -H "Content-Type: application/json" \
      -H "kbn-xsrf: true" \
      -d '{"attributes":{"title":"jenkins-*","timeFieldName":"@timestamp"}}' || true
    
    curl -X POST "localhost:5601/api/saved_objects/index-pattern/sonarqube-*" \
      -H "Content-Type: application/json" \
      -H "kbn-xsrf: true" \
      -d '{"attributes":{"title":"sonarqube-*","timeFieldName":"@timestamp"}}' || true
    
    curl -X POST "localhost:5601/api/saved_objects/index-pattern/tomcat-*" \
      -H "Content-Type: application/json" \
      -H "kbn-xsrf: true" \
      -d '{"attributes":{"title":"tomcat-*","timeFieldName":"@timestamp"}}' || true
    
    echo "📊 ELK Stack is ready!"
else
    echo "❌ ELK Stack installation failed!"
    docker-compose -f elk-compose.yml logs
    exit 1
fi