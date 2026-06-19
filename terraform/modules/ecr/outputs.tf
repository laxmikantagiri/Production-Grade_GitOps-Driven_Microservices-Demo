output "repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
output "repository_arns" {
  value = [for v in aws_ecr_repository.services : v.arn]
}
output "registry_url" {
  value = "${var.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}
