# Variables for ELK-Terraform-Challenge
variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-0945610b37068d87a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.2xlarge"
}

variable "key_name" {
  description = "Key pair name for EC2 access"
  type        = string
  default     = "Pair06"
}

variable "instance_name" {
  description = "Name tag for EC2 instance"
  type        = string
  default     = "ELK-Terraform-Challenge101"
}

variable "jenkins_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "jenkins_password" {
  description = "Jenkins admin password"
  type        = string
  default     = "admin"
}

variable "sonarqube_user" {
  description = "SonarQube admin username"
  type        = string
  default     = "admin"
}

variable "sonarqube_password" {
  description = "SonarQube admin password"
  type        = string
  default     = "admin"
}

variable "tomcat_username" {
  description = "Tomcat admin username"
  type        = string
  default     = "admin"
}

variable "tomcat_password" {
  description = "Tomcat admin password"
  type        = string
  default     = "admin"
}