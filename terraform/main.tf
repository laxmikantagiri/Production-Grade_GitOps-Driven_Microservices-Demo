# ============================================================
# DATA SOURCES
# ============================================================
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ============================================================
# VPC
# ============================================================
module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
}

# ============================================================
# EKS CLUSTER + MANAGED NODE GROUP + AWS ADDONS
# ============================================================
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  environment     = var.environment

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  public_subnets  = module.vpc.public_subnet_ids

  node_instance_type = var.node_instance_type
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  node_desired_size  = var.node_desired_size
}

# ============================================================
# ECR REPOSITORIES (one per service)
# ============================================================
module "ecr" {
  source = "./modules/ecr"

  services    = var.services
  environment = var.environment
}

# ============================================================
# IAM (GitHub Actions OIDC + Pod Identity roles)
# ============================================================
module "iam" {
  source = "./modules/iam"

  aws_region   = var.aws_region
  account_id   = data.aws_caller_identity.current.account_id
  cluster_name = var.cluster_name
  github_org   = var.github_org
  github_repo  = var.github_repo
  services     = var.services

  # Pod Identity associations need OIDC provider from EKS
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

# ============================================================
# BASTION HOST (SSM only, no SSH keys)
# ============================================================
module "bastion" {
  source = "./modules/bastion"

  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnet_ids
  cluster_name   = var.cluster_name
}

# ============================================================
# HELM RELEASES (cluster tooling)
# ============================================================
module "helm" {
  source = "./modules/helm"

  cluster_name = var.cluster_name
  aws_region   = var.aws_region
  vpc_id       = module.vpc.vpc_id

  # IAM role ARNs for controllers (Pod Identity)
  lbc_role_arn                = module.iam.lbc_role_arn
  cluster_autoscaler_role_arn = module.iam.cluster_autoscaler_role_arn

  argocd_notification_email = var.argocd_notification_email
  account_id                = data.aws_caller_identity.current.account_id
  gmail_app_password        = var.gmail_app_password
  git_token                 = var.git_token

  depends_on = [module.eks, module.iam]
}
