variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used in resource names and tags"
  type        = string
  default     = "todo-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ssh_cidr" {
  description = "Your public IP in CIDR form for SSH to Jenkins (e.g. 1.2.3.4/32). Find yours at https://ifconfig.me"
  type        = string
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins controller"
  type        = string
  default     = "t3.small"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS (must be a version with available worker AMIs in your region)"
  type        = string
  default     = "1.30"
}

variable "ssh_key_name" {
  description = "Name of an existing AWS EC2 key pair for SSH access to Jenkins"
  type        = string
}

variable "mongodb_uri" {
  description = "MongoDB Atlas connection string (stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "frontend_url" {
  description = "Public app URL for backend CORS (update after first K8s deploy with NLB DNS)"
  type        = string
  default     = "http://localhost"
}
