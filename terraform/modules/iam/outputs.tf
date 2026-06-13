output "github_actions_role_arn"      { value = aws_iam_role.github_actions.arn }
output "lbc_role_arn"                 { value = aws_iam_role.lbc.arn }
output "cluster_autoscaler_role_arn"  { value = aws_iam_role.cluster_autoscaler.arn }
output "ebs_csi_role_arn"             { value = aws_iam_role.ebs_csi.arn }
