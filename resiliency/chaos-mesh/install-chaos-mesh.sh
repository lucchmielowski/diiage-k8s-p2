#!/bin/bash
# Install Chaos Mesh on Kubernetes cluster

set -e

echo "🔧 Installing Chaos Mesh..."

# Add Chaos Mesh Helm repository
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Create namespace for Chaos Mesh
kubectl create namespace chaos-mesh --dry-run=client -o yaml | kubectl apply -f -

# Install Chaos Mesh with CRDs
helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.create=true \
  --wait

echo "✅ Chaos Mesh installed successfully!"
echo ""
echo "📊 Access Chaos Mesh Dashboard:"
echo "   kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333"
echo "   Then open: http://localhost:2333"
echo ""
echo "🔍 Verify installation:"
echo "   kubectl get pods -n chaos-mesh"
echo "   kubectl get crds | grep chaos-mesh"
