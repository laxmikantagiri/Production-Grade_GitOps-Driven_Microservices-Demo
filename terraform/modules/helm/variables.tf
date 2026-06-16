variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — passed to AWS Load Balancer Controller"
  type        = string
}

variable "lbc_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (Pod Identity)"
  type        = string
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler (Pod Identity)"
  type        = string
}

variable "argocd_notification_email" {
  description = "Email address for ArgoCD sync/health notifications"
  type        = string
}


variable "account_id" {
  description = "AWS account ID — used for ECR registry URL in image updater"
  type        = string
}

variable "gmail_app_password" {
  description = "Gmail App Password for SMTP notifications (ArgoCD + Alertmanager)"
  type        = string
  sensitive   = true
}

variable "git_token" {
  description = "GitHub PAT for ArgoCD Image Updater git write-back"
  type        = string
  sensitive   = true
}

variable "git_token" {
  description = "GitHub PAT for ArgoCD Image Updater git write-back"
  type        = string
  sensitive   = true
}

variable "git_token" {
  description = "GitHub PAT for ArgoCD Image Updater git write-back"
  type        = string
  sensitive   = true
}

variable "git_token" {
  description = "GitHub PAT for ArgoCD Image Updater git write-back"
  type        = string
  sensitive   = true
}
