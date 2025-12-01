#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing Kyverno...${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}helm is not installed. Please install helm first.${NC}"
    exit 1
fi

# Add Kyverno Helm repository
echo -e "${YELLOW}Adding Kyverno Helm repository...${NC}"
helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || echo "Kyverno repo already added"
helm repo update

# Install Kyverno
echo -e "${YELLOW}Installing Kyverno via Helm...${NC}"
helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --wait \
    --timeout 5m

# Wait for Kyverno to be ready
echo -e "${YELLOW}Waiting for Kyverno to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s \
    deployment/kyverno-admission-controller \
    deployment/kyverno-background-controller \
    deployment/kyverno-cleanup-controller \
    deployment/kyverno-reports-controller \
    -n kyverno

echo -e "${GREEN}✓ Kyverno installed successfully!${NC}"
echo ""
echo "To verify installation:"
echo "  kubectl get pods -n kyverno"
echo ""
echo "To install Kyverno policies:"
echo "  kubectl apply -f kyverno/policies/"
