output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.elk_terraform_instance.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.elk_terraform_instance.public_dns
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_instance.elk_terraform_instance.public_ip}:8080"
}

output "sonarqube_url" {
  description = "SonarQube URL"
  value       = "http://${aws_instance.elk_terraform_instance.public_ip}:9000"
}

output "kibana_url" {
  description = "Kibana URL"
  value       = "http://${aws_instance.elk_terraform_instance.public_ip}:5601"
}

output "elasticsearch_url" {
  description = "Elasticsearch URL"
  value       = "http://${aws_instance.elk_terraform_instance.public_ip}:9200"
}

output "tomcat_url" {
  description = "Tomcat URL"
  value       = "http://${aws_instance.elk_terraform_instance.public_ip}:8081"
}

output "react_app_url" {
  description = "React App URL"
  value       = "http://${aws_instance.elk_terraform_instance.public_ip}:8081/group6-react-app"
}

output "access_info" {
  description = "Access information for all services"
  value = <<-EOT
🚀 ELK-Terraform-Challenge101 Deployment Complete!

📍 Instance Details:
├── Public IP: ${aws_instance.elk_terraform_instance.public_ip}
├── Public DNS: ${aws_instance.elk_terraform_instance.public_dns}
└── Instance ID: ${aws_instance.elk_terraform_instance.id}

🔗 Service URLs:
├── Jenkins:     http://${aws_instance.elk_terraform_instance.public_ip}:8080
├── SonarQube:   http://${aws_instance.elk_terraform_instance.public_ip}:9000
├── Kibana:      http://${aws_instance.elk_terraform_instance.public_ip}:5601
├── Elasticsearch: http://${aws_instance.elk_terraform_instance.public_ip}:9200
├── Tomcat:      http://${aws_instance.elk_terraform_instance.public_ip}:8081
└── React App:   http://${aws_instance.elk_terraform_instance.public_ip}:8081/group6-react-app

🔑 Default Credentials:
├── Jenkins:    ${var.jenkins_user}/${var.jenkins_password}
├── SonarQube:  ${var.sonarqube_user}/${var.sonarqube_password}
└── Tomcat:     ${var.tomcat_username}/${var.tomcat_password}

⏱️  Services are starting up... Please wait 5-10 minutes for full initialization.
💡 Check Jenkins for the auto-created 'group6-react-app-pipeline' job!
EOT
}