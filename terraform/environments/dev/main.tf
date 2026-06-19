data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = "microservices-demo-${var.environment}"
  account_id   = var.aws_account_id
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)

  services = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "loadgenerator",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice",
    "shoppingassistantservice",
  ]
}

module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  cluster_name         = local.cluster_name
  azs                  = local.azs
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
}

module "ecr" {
  source = "../../modules/ecr"

  environment = var.environment
  services    = local.services
  account_id  = local.account_id
  aws_region  = var.aws_region
}

module "eks" {
  source = "../../modules/eks"

  environment        = var.environment
  cluster_name       = local.cluster_name
  cluster_version    = var.cluster_version
  aws_region         = var.aws_region
  account_id         = local.account_id
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type

  vpc_cni_irsa_role_arn                 = module.iam.vpc_cni_irsa_role_arn
  aws_load_balancer_controller_role_arn = module.iam.aws_load_balancer_controller_role_arn
  external_secrets_irsa_role_arn        = module.iam.external_secrets_irsa_role_arn
  argocd_image_updater_irsa_role_arn    = module.iam.argocd_image_updater_irsa_role_arn
}

module "iam" {
  source = "../../modules/iam"

  environment        = var.environment
  cluster_name       = local.cluster_name
  account_id         = local.account_id
  aws_region         = var.aws_region
  github_org         = var.github_org
  github_source_repo = var.github_source_repo
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  ecr_repo_arns      = module.ecr.repository_arns
}
