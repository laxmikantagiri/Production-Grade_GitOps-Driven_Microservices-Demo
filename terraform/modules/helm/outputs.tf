output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  value       = "argocd"
}


output "monitoring_namespace" {
  description = "Namespace where kube-prometheus-stack is deployed"
  value       = "monitoring"
}
