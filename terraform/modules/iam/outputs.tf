output "github_actions_role_arn"              { value = aws_iam_role.github_actions.arn }
output "vpc_cni_irsa_role_arn"                { value = aws_iam_role.vpc_cni.arn }
output "aws_load_balancer_controller_role_arn" { value = aws_iam_role.aws_load_balancer_controller.arn }
output "external_secrets_irsa_role_arn"       { value = aws_iam_role.external_secrets.arn }
output "argocd_image_updater_irsa_role_arn"   { value = aws_iam_role.argocd_image_updater.arn }
output "github_oidc_provider_arn"             { value = aws_iam_openid_connect_provider.github.arn }
