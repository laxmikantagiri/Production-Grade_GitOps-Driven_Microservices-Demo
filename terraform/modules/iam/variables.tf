variable "aws_region"        { type = string }
variable "account_id"        { type = string }
variable "cluster_name"      { type = string }
variable "github_org"        { type = string }
variable "github_repo"       { type = string }
variable "services"          { type = list(string) }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
