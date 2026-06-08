output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "jenkins_elastic_ip" {
  description = "Elastic IP for Jenkins — use for GitHub webhook and SSH (always use THIS IP, not the instance auto-assigned IP)"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_instance_id" {
  description = "Current Jenkins EC2 instance ID — verify Elastic IP is associated in AWS Console"
  value       = aws_instance.jenkins.id
}

output "jenkins_url" {
  description = "Jenkins web UI URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "jenkins_initial_password_command" {
  description = "Run on Jenkins EC2 after first boot to get admin password"
  value       = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}

output "jenkins_ssh_command" {
  description = "SSH into Jenkins EC2 (replace path to your .pem key)"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_eip.jenkins.public_ip}"
}

output "eks_cluster_name" {
  description = "EKS cluster name for kubectl and Jenkins pipeline"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_backend_url" {
  description = "ECR repository URL for backend images"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_url" {
  description = "ECR repository URL for frontend images"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_registry" {
  description = "ECR registry host (account.dkr.ecr.region.amazonaws.com)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "secrets_manager_arn" {
  description = "ARN of the app secrets in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.app.arn
}

output "secrets_manager_name" {
  description = "Name of the app secrets in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.app.name
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform remote state (optional migration)"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "configure_kubectl_command" {
  description = "Run locally or on Jenkins to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "eso_irsa_role_arn" {
  description = "IAM role ARN for External Secrets Operator service account"
  value       = module.eso_irsa.iam_role_arn
}
