variable "environment"        { type = string }
variable "cluster_name"       { type = string }
variable "cluster_version"    { type = string }
variable "aws_region"         { type = string }
variable "account_id"         { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids"  { type = list(string) }
variable "node_instance_type" { type = string; default = "t3.small" }
variable "vpc_cni_irsa_role_arn"                 { type = string }
variable "aws_load_balancer_controller_role_arn"  { type = string }
variable "external_secrets_irsa_role_arn"         { type = string }
variable "argocd_image_updater_irsa_role_arn"     { type = string }
