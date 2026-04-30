#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f gitops/apps/platform-apps.yaml

echo "Argo CD installed. Access with: kubectl port-forward svc/argocd-server -n argocd 8088:443"
