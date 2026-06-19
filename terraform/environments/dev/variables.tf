variable "aws_region" {
  type    = string
  default = "ap-south-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Must be a valid AWS region (e.g. ap-south-1)."
  }
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "aws_account_id" {
  type    = string
  default = "803146828684"
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Must be exactly 12 digits."
  }
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "github_org" {
  type    = string
  default = "meAnshu"
}

variable "github_source_repo" {
  type    = string
  default = "Production-Grade_GitOps-Driven_Microservices-Demo"
}

variable "node_instance_type" {
  type    = string
  default = "t3.small"
}
