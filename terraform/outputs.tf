output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64)"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Run this command to update your local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "bastion_instance_id" {
  description = "Bastion EC2 instance ID — use with SSM Session Manager"
  value       = module.bastion.instance_id
}

output "bastion_ssm_command" {
  description = "Command to open an SSM session to the bastion host"
  value       = "aws ssm start-session --target ${module.bastion.instance_id} --region ${var.aws_region}"
}

output "ecr_repository_urls" {
  description = "Map of service name to ECR repository URL"
  value       = module.ecr.repository_urls
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — add to repo secrets as AWS_ROLE_ARN"
  value       = module.iam.github_actions_role_arn
}
