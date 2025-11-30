#!/bin/bash

set -e

echo "Installing ArgoCD via Helm..."

# Add ArgoCD Helm repository
echo "Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo update

# Create argocd namespace if it doesn't exist
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "Installing ArgoCD chart..."
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=NodePort \
  --set server.insecure=true \
  --version 5.51.6

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "ArgoCD installation completed!"
echo ""
echo "To access ArgoCD:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
