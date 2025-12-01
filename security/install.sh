#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

print_header "Kubernetes Security Demo Installation"
echo "This script will install:"
echo "  - Namespace (security-demo)"
echo "  - RBAC (ServiceAccounts, Roles, RoleBindings)"
echo "  - Network Policies (default-deny + allow rules)"
echo "  - Demo Applications (frontend, backend, database)"
echo ""
echo "Optional:"
echo "  - Kyverno (policy engine) - run kyverno/install-kyverno.sh separately"
echo ""
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled."
    exit 0
fi

# Step 1: Create namespace
print_header "Step 1/5: Creating namespace"
kubectl apply -f namespace.yaml
print_success "Namespace created"

# Step 2: Deploy RBAC
print_header "Step 2/5: Deploying RBAC (ServiceAccounts, Roles, RoleBindings)"

print_info "Creating ServiceAccounts..."
kubectl apply -f rbac/service-accounts.yaml

print_info "Creating Roles..."
kubectl apply -f rbac/roles.yaml

print_info "Creating RoleBindings..."
kubectl apply -f rbac/role-bindings.yaml

print_success "RBAC configured"

# Step 3: Deploy Network Policies
print_header "Step 3/5: Deploying Network Policies"

print_info "Creating default-deny policies..."
kubectl apply -f network-policies/default-deny.yaml

print_info "Creating allow policies..."
kubectl apply -f network-policies/allow-policies.yaml

print_success "Network Policies configured"

# Step 4: Deploy demo applications
print_header "Step 4/5: Deploying demo applications"

print_info "Deploying frontend..."
kubectl apply -f demo-apps/frontend.yaml

print_info "Deploying backend..."
kubectl apply -f demo-apps/backend.yaml

print_info "Deploying database..."
kubectl apply -f demo-apps/database.yaml

print_info "Waiting for applications to be ready..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/frontend \
    deployment/backend \
    deployment/database \
    -n security-demo

print_success "Demo applications deployed"

# Step 5: Verify installation
print_header "Step 5/5: Verifying installation"

echo "Checking pods status..."
kubectl get pods -n security-demo

echo ""
echo "Checking services..."
kubectl get svc -n security-demo

echo ""
echo "Checking network policies..."
kubectl get networkpolicies -n security-demo

# Summary
print_header "Installation Complete! 🎉"

echo -e "${GREEN}Security demo is now running!${NC}\n"

echo "Components installed:"
echo "  ✓ Namespace: security-demo"
echo "  ✓ ServiceAccounts: readonly-user, developer-user, admin-user"
echo "  ✓ Roles: readonly-role, developer-role, admin-role"
echo "  ✓ RoleBindings: linked ServiceAccounts to Roles"
echo "  ✓ Network Policies: default-deny + allow rules"
echo "  ✓ Demo Apps: frontend (2 replicas), backend (2 replicas), database (1 replica)"
echo ""

echo "To test RBAC permissions:"
echo "  # Get token for readonly-user"
echo "  kubectl create token readonly-user -n security-demo"
echo ""
echo "  # Try to list pods (should work)"
echo "  kubectl get pods -n security-demo --token=<TOKEN>"
echo ""
echo "  # Try to create a pod (should fail)"
echo "  kubectl run test --image=nginx -n security-demo --token=<TOKEN>"
echo ""

echo "To test Network Policies:"
echo "  # Test frontend to backend (should work)"
echo "  kubectl exec -n security-demo deployment/frontend -- wget -qO- http://backend:8080"
echo ""
echo "  # Test frontend to database (should fail - no policy allows this)"
echo "  kubectl exec -n security-demo deployment/frontend -- wget -qO- --timeout=3 http://database:5432 || echo 'Connection blocked by NetworkPolicy'"
echo ""

echo "To install Kyverno and policies:"
echo "  cd kyverno"
echo "  chmod +x install-kyverno.sh"
echo "  ./install-kyverno.sh"
echo ""
echo "  # After Kyverno is installed, apply policies:"
echo "  kubectl apply -f policies/"
echo ""

echo "To view resources:"
echo "  kubectl get all,serviceaccounts,roles,rolebindings,networkpolicies -n security-demo"
echo ""

echo "For more information, see: security/README.md"
echo ""

print_success "Happy securing! 🔒"
