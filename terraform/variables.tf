variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "boutique-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "github_org" {
  description = "GitHub organization or username for OIDC trust"
  type        = string
  default     = "meAnshu"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "Production-Grade_GitOps-Driven_Microservices-Demo"
}

variable "argocd_notification_email" {
  description = "Email address for ArgoCD notifications"
  type        = string
  default     = "anshuu.verma@gmail.com"
}

# List of all microservices that get ECR repositories
variable "services" {
  description = "List of microservice names — one ECR repo per service"
  type        = list(string)
  default = [
    "frontend",
    "cartservice",
    "productcatalogservice",
    "currencyservice",
    "paymentservice",
    "shippingservice",
    "checkoutservice",
    "recommendationservice",
    "emailservice",
    "adservice",
    "shoppingassistantservice",
    "loadgenerator"
  ]
}

