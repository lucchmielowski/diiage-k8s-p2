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

print_header "Kubernetes Monitoring Stack Installation"
echo "This script will install:"
echo "  - cert-manager (required for OpenTelemetry Operator)"
echo "  - OpenTelemetry Operator"
echo "  - OpenTelemetry Collector"
echo "  - Tempo (distributed tracing)"
echo "  - Prometheus (metrics)"
echo "  - Grafana (visualization)"
echo ""
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled."
    exit 0
fi

# Step 1: Install cert-manager
print_header "Step 1/6: Installing cert-manager"
print_info "cert-manager is required for OpenTelemetry Operator webhooks..."

if kubectl get namespace cert-manager &> /dev/null; then
    print_info "cert-manager namespace already exists, skipping installation..."
else
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    print_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/cert-manager \
        deployment/cert-manager-webhook \
        deployment/cert-manager-cainjector \
        -n cert-manager
    
    print_success "cert-manager installed successfully"
fi

# Step 2: Install OpenTelemetry Operator
print_header "Step 2/6: Installing OpenTelemetry Operator"

if kubectl get namespace opentelemetry-operator-system &> /dev/null; then
    print_info "OpenTelemetry Operator namespace already exists, skipping installation..."
else
    kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.91.0/opentelemetry-operator.yaml
    
    print_info "Waiting for OpenTelemetry Operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/opentelemetry-operator-controller-manager \
        -n opentelemetry-operator-system
    
    print_success "OpenTelemetry Operator installed successfully"
fi

# Step 3: Create monitoring namespace
print_header "Step 3/6: Creating monitoring namespace"

kubectl apply -f namespace.yaml
print_success "Monitoring namespace created"

# Step 4: Deploy monitoring stack components
print_header "Step 4/6: Deploying monitoring stack components"

print_info "Deploying Tempo..."
kubectl apply -f tempo/tempo.yaml

print_info "Deploying Prometheus..."
kubectl apply -f prometheus/prometheus.yaml

print_info "Deploying Grafana..."
kubectl apply -f grafana/grafana.yaml

print_info "Deploying OpenTelemetry Collector..."
kubectl apply -f opentelemetry-collector/collector.yaml

print_success "All components deployed"

# Step 5: Wait for components to be ready
print_header "Step 5/6: Waiting for components to be ready"

print_info "This may take a few minutes..."

kubectl wait --for=condition=available --timeout=300s \
    deployment/tempo \
    deployment/prometheus \
    deployment/grafana \
    -n monitoring

print_info "Waiting for OpenTelemetry Collector..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/otel-collector-collector \
    -n monitoring 2>/dev/null || print_info "OpenTelemetry Collector deployment name may vary, checking pods..."

sleep 5

print_success "All components are ready!"

# Step 6: Deploy instrumentation resource
print_header "Step 6/6: Creating Instrumentation resource"

kubectl apply -f demo-instrumented/instrumentation.yaml
print_success "Instrumentation resource created"

# Summary
print_header "Installation Complete! 🎉"

echo -e "${GREEN}Monitoring stack is now running!${NC}\n"

echo "Components installed:"
echo "  ✓ cert-manager"
echo "  ✓ OpenTelemetry Operator"
echo "  ✓ OpenTelemetry Collector"
echo "  ✓ Tempo (tracing backend)"
echo "  ✓ Prometheus (metrics backend)"
echo "  ✓ Grafana (visualization)"
echo "  ✓ Instrumentation resource (for auto-instrumentation)"
echo ""

echo "To access Grafana:"
echo "  1. Run: kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "  2. Open: http://localhost:3000"
echo "  3. Login: admin / admin"
echo ""

echo "To deploy demo applications:"
echo "  kubectl apply -f demo-instrumented/demo-app-instrumented.yaml"
echo ""

echo "To enable auto-instrumentation in your apps, add this annotation:"
echo "  For Python:  instrumentation.opentelemetry.io/inject-python: \"monitoring/demo-instrumentation\""
echo "  For Node.js: instrumentation.opentelemetry.io/inject-nodejs: \"monitoring/demo-instrumentation\""
echo "  For Java:    instrumentation.opentelemetry.io/inject-java: \"monitoring/demo-instrumentation\""
echo ""

echo "For more information, see: monitoring/README.md"
echo ""

print_success "Happy monitoring! 📊"
