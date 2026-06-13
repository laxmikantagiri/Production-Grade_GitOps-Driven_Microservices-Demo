output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  value       = "argocd"
}

output "nginx_ingress_namespace" {
  description = "Namespace where NGINX Ingress Controller is deployed"
  value       = "ingress-nginx"
}

output "monitoring_namespace" {
  description = "Namespace where kube-prometheus-stack is deployed"
  value       = "monitoring"
}
