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
