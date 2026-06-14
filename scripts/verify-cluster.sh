#!/bin/bash
set -e

echo "===== Nodes ====="
kubectl get nodes

echo
echo "===== Namespaces ====="
kubectl get ns

echo
echo "===== ArgoCD ====="
kubectl get pods -n argocd || true

echo
echo "===== Monitoring ====="
kubectl get pods -n monitoring || true

echo
echo "===== Ingress ====="
kubectl get ingress -A || true
