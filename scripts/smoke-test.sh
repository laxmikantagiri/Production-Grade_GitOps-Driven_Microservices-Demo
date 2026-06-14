#!/bin/bash
set -e

kubectl get pods -n boutique-app

kubectl get svc -n boutique-app

kubectl get ingress -n boutique-app

echo
echo "Smoke test passed"
