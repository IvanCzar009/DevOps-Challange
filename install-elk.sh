#!/bin/bash

# ELK Stack Installation Script
# Installs Elasticsearch, Logstash, and Kibana using Docker

set -e

# Log all output
exec > >(tee /var/log/elk-installation.log) 2>&1

echo "Starting ELK Stack installation at $(date)"

# Get public IP for configuration
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Instance Public IP: $PUBLIC_IP"

# Load integration helper if available
if [ -f "$(dirname "$0")/integration-helper.sh" ]; then
    source "$(dirname "$0")/integration-helper.sh"
fi

# Update system
echo "Updating system packages..."
yum update -y

# Ensure Docker is installed (using integration helper)
if command -v ensure_docker &> /dev/null; then
    ensure_docker
else
    # Fallback installation
    echo "Installing Docker..."
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Create ELK directory
echo "Creating ELK stack directory..."
mkdir -p /home/ec2-user/elk-stack
cd /home/ec2-user/elk-stack

# Create docker-compose.yml for ELK stack
echo "Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.0
    container_name: elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=elk-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    networks:
      - elk

  logstash:
    image: docker.elastic.co/logstash/logstash:8.10.0
    container_name: logstash
    volumes:
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    ports:
      - "5044:5044"
      - "5000:5000/tcp"
      - "5000:5000/udp"
      - "9600:9600"
    environment:
      LS_JAVA_OPTS: "-Xmx1g -Xms1g"
    networks:
      - elk
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.10.0
    container_name: kibana
    ports:
      - "5061:5601"
    environment:
      ELASTICSEARCH_URL: http://elasticsearch:9200
      ELASTICSEARCH_HOSTS: '["http://elasticsearch:9200"]'
    networks:
      - elk
    depends_on:
      - elasticsearch

volumes:
  elasticsearch-data:
    driver: local

networks:
  elk:
    driver: bridge
EOF

# Create Logstash configuration directory
echo "Creating Logstash configuration..."
mkdir -p logstash/config logstash/pipeline

# Create Logstash configuration
cat > logstash/config/logstash.yml << 'EOF'
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: [ "http://elasticsearch:9200" ]
EOF

# Create Logstash pipeline configuration
cat > logstash/pipeline/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
  tcp {
    port => 5000
  }
  # Input for various application logs
  file {
    path => "/var/log/**/*.log"
    start_position => "beginning"
    tags => ["system"]
  }
}

filter {
  # System logs processing
  if "system" in [tags] {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:timestamp} %{IPORHOST:server} %{DATA:program}(?:\\[%{POSINT:pid}\\])?: %{GREEDYDATA:message}" }
    }
    date {
      match => [ "timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
    mutate {
      add_field => { "service" => "system" }
    }
  }
  
  # Application logs processing
  if [fields][app] {
    mutate {
      add_field => { "application" => "%{[fields][app]}" }
    }
  }
  
  # Add server information
  mutate {
    add_field => { 
      "server_ip" => "HOST_IP_PLACEHOLDER"
      "environment" => "production"
    }
  }
}

output {
  elasticsearch {
    hosts => "elasticsearch:9200"
    index => "logstash-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

# Replace placeholder with actual IP
sed -i "s/HOST_IP_PLACEHOLDER/$PUBLIC_IP/g" logstash/pipeline/logstash.conf

# Set proper ownership
echo "Setting proper ownership..."
chown -R ec2-user:ec2-user /home/ec2-user/elk-stack

# Increase virtual memory map count for Elasticsearch
echo "Configuring system settings for Elasticsearch..."
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
sysctl -p

# Create ELK management script
echo "Creating ELK management script..."
cat > /home/ec2-user/elk-stack/manage-elk.sh << 'EOF'
#!/bin/bash

case "$1" in
  start)
    echo "Starting ELK stack..."
    docker-compose up -d
    ;;
  stop)
    echo "Stopping ELK stack..."
    docker-compose down
    ;;
  restart)
    echo "Restarting ELK stack..."
    docker-compose down
    docker-compose up -d
    ;;
  status)
    echo "ELK stack status:"
    docker-compose ps
    ;;
  logs)
    docker-compose logs -f
    ;;
  health)
    echo "Checking ELK stack health..."
    echo "Elasticsearch:"
    curl -s http://localhost:9200/_cluster/health?pretty
    echo -e "\nKibana:"
    curl -s http://localhost:5061/api/status
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs|health}"
    exit 1
esac
EOF

chmod +x /home/ec2-user/elk-stack/manage-elk.sh
chown ec2-user:ec2-user /home/ec2-user/elk-stack/manage-elk.sh

# Start ELK stack
echo "Starting ELK stack..."
cd /home/ec2-user/elk-stack
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start up..."
sleep 120

# Check and log status
echo "Checking ELK stack status..."
docker-compose ps > /var/log/elk-stack-status.log

# Test services
echo "Testing service connections..."
for i in {1..10}; do
  if curl -s http://localhost:9200/_cluster/health > /dev/null; then
    echo "Elasticsearch is running!" >> /var/log/elk-installation.log
    break
  fi
  echo "Waiting for Elasticsearch... attempt $i"
  sleep 30
done

for i in {1..10}; do
  if curl -s http://localhost:5061/api/status > /dev/null; then
    echo "Kibana is running!" >> /var/log/elk-installation.log
    break
  fi
  echo "Waiting for Kibana... attempt $i"
  sleep 30
done

# Create systemd service for auto-start
echo "Creating systemd service for ELK stack..."
cat > /etc/systemd/system/elk-stack.service << 'EOF'
[Unit]
Description=ELK Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/elk-stack
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0
User=ec2-user
Group=docker

[Install]
WantedBy=multi-user.target
EOF

systemctl enable elk-stack.service

# Create service information file
cat > /home/ec2-user/elk-info.txt << EOF
ELK Stack Installation Information
=================================

Services:
- Elasticsearch: http://$PUBLIC_IP:9200
- Kibana: http://$PUBLIC_IP:5061
- Logstash: $PUBLIC_IP:5044 (Beats), $PUBLIC_IP:5000 (TCP/UDP)

Management Commands:
- Start: cd ~/elk-stack && ./manage-elk.sh start
- Stop: cd ~/elk-stack && ./manage-elk.sh stop
- Status: cd ~/elk-stack && ./manage-elk.sh status
- Logs: cd ~/elk-stack && ./manage-elk.sh logs
- Health: cd ~/elk-stack && ./manage-elk.sh health

Configuration:
- Docker Compose: ~/elk-stack/docker-compose.yml
- Logstash Config: ~/elk-stack/logstash/config/
- Logstash Pipeline: ~/elk-stack/logstash/pipeline/

Installation completed at: $(date)
EOF

chown ec2-user:ec2-user /home/ec2-user/elk-info.txt

echo "ELK Stack installation completed successfully!"
echo "Access Kibana at: http://$PUBLIC_IP:5061"
echo "Access Elasticsearch at: http://$PUBLIC_IP:9200"