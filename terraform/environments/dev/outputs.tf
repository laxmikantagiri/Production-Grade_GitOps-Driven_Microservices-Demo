output "vpc_id"                { value = module.vpc.vpc_id }
output "private_subnet_ids"    { value = module.vpc.private_subnet_ids }
output "public_subnet_ids"     { value = module.vpc.public_subnet_ids }
output "cluster_name"          { value = module.eks.cluster_name }
output "cluster_endpoint"      { value = module.eks.cluster_endpoint; sensitive = true }
output "ecr_repository_urls"   { value = module.ecr.repository_urls }
output "github_actions_role_arn"               { value = module.iam.github_actions_role_arn }
output "aws_load_balancer_controller_role_arn" { value = module.iam.aws_load_balancer_controller_role_arn }
output "external_secrets_irsa_role_arn"        { value = module.iam.external_secrets_irsa_role_arn }
output "argocd_image_updater_irsa_role_arn"    { value = module.iam.argocd_image_updater_irsa_role_arn }
output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ap-south-1 --name ${module.eks.cluster_name}"
}
