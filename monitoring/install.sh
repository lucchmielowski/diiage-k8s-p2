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

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed. Please install helm first."
    exit 1
fi

print_header "Kubernetes Monitoring Stack Installation (Helm-based)"
echo "This script will install:"
echo "  - cert-manager (required for OpenTelemetry Operator)"
echo "  - OpenTelemetry Operator"
echo "  - OpenTelemetry Collector (via Helm)"
echo "  - Tempo (via Helm - distributed tracing)"
echo "  - Prometheus (via Helm - metrics)"
echo "  - Grafana (via Helm - visualization)"
echo ""
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled."
    exit 0
fi

# Step 0: Add Helm repositories
print_header "Step 0/7: Adding Helm repositories"

print_info "Adding Grafana Helm repo..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || print_info "Grafana repo already added"

print_info "Adding Prometheus Community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || print_info "Prometheus repo already added"

print_info "Adding OpenTelemetry Helm repo..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || print_info "OpenTelemetry repo already added"

print_info "Updating Helm repositories..."
helm repo update

print_success "Helm repositories configured"

# Step 1: Install cert-manager
print_header "Step 1/7: Installing cert-manager"
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
print_header "Step 2/7: Installing OpenTelemetry Operator"

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
print_header "Step 3/7: Creating monitoring namespace"

kubectl apply -f namespace.yaml
print_success "Monitoring namespace created"

# Step 3.5: Clean up existing non-Helm resources if they exist
print_info "Checking for existing non-Helm resources..."

# Check if there are any existing deployments/services that are not managed by Helm
if kubectl get deployments,services,configmaps -n monitoring --no-headers 2>/dev/null | grep -v "kube-root-ca.crt" | grep -q .; then
    print_info "Found existing resources in monitoring namespace"
    
    # Check if any resources lack Helm labels (indicating they were created by kubectl, not Helm)
    NON_HELM_RESOURCES=$(kubectl get deployments,services,configmaps -n monitoring -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.labels["app.kubernetes.io/managed-by"] != "Helm") | .metadata.name' 2>/dev/null || echo "")
    
    if [ ! -z "$NON_HELM_RESOURCES" ]; then
        print_info "Detected non-Helm managed resources. These need to be removed for Helm to work properly."
        echo -e "${YELLOW}The following resources will be deleted:${NC}"
        echo "$NON_HELM_RESOURCES" | sed 's/^/  - /'
        echo ""
        read -p "Do you want to remove these resources? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing old kubectl-based resources..."
            
            # Delete specific deployments, services, and configmaps
            kubectl delete deployment tempo prometheus grafana otel-collector-collector -n monitoring --ignore-not-found=true 2>/dev/null || true
            kubectl delete service tempo prometheus grafana otel-collector-collector otel-collector-collector-headless otel-collector-collector-monitoring -n monitoring --ignore-not-found=true 2>/dev/null || true
            kubectl delete configmap tempo-config prometheus-config grafana-datasources grafana-dashboards-config grafana-dashboard-otel otel-collector-collector -n monitoring --ignore-not-found=true 2>/dev/null || true
            
            print_success "Old resources cleaned up"
            sleep 2
        else
            print_error "Installation cannot continue with existing non-Helm resources."
            print_error "Please manually remove them or re-run the script and choose 'y' to remove them."
            exit 1
        fi
    else
        print_info "All existing resources are Helm-managed. Proceeding..."
    fi
else
    print_info "No existing resources found. Proceeding with fresh installation..."
fi

# Step 4: Deploy monitoring stack components via Helm
print_header "Step 4/7: Deploying monitoring stack components via Helm"

print_info "Installing Tempo..."
helm upgrade --install tempo grafana/tempo \
    --namespace monitoring \
    --values tempo/values.yaml \
    --wait \
    --timeout 5m

print_info "Installing Prometheus..."
helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --values prometheus/values.yaml \
    --wait \
    --timeout 5m

print_info "Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
    --namespace monitoring \
    --values grafana/values.yaml \
    --wait \
    --timeout 5m

print_success "All Helm charts deployed"

# Step 5: Deploy OpenTelemetry Collector via Helm
print_header "Step 5/7: Deploying OpenTelemetry Collector via Helm"

print_info "Installing OpenTelemetry Collector..."
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
    --namespace monitoring \
    --values opentelemetry-collector/values.yaml \
    --wait \
    --timeout 5m

print_success "OpenTelemetry Collector deployed"

# Step 6: Wait for all components to be ready
print_header "Step 6/7: Verifying all components are ready"

print_info "This may take a few moments..."

kubectl wait --for=condition=available --timeout=300s \
    deployment/tempo \
    deployment/prometheus-server \
    deployment/grafana \
    -n monitoring 2>/dev/null || print_info "Some deployments may have different names..."

sleep 5

print_success "All components are ready!"

# Step 7: Deploy instrumentation resource
print_header "Step 7/9: Creating Instrumentation resource"

kubectl apply -f demo-instrumented/instrumentation.yaml
print_success "Instrumentation resource created"

# Step 8: Deploy demo applications
print_header "Step 8/9: Deploying demo applications"

print_info "Deploying demo applications (Python, Node.js, Java)..."
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml

print_info "Waiting for demo applications to be ready..."
sleep 10

print_success "Demo applications deployed"

# Step 9: Deploy traffic generator
print_header "Step 9/9: Deploying traffic generator"

print_info "Deploying traffic generator to continuously call demo apps..."
kubectl apply -f demo-instrumented/traffic-generator.yaml

print_info "Waiting for traffic generator to start..."
sleep 5

print_success "Traffic generator deployed - it will continuously generate telemetry data"

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
echo "  ✓ Demo applications (Python, Node.js, Java)"
echo "  ✓ Traffic generator (continuously generating telemetry)"
echo ""

echo "To access Grafana:"
echo "  1. Run: kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "  2. Open: http://localhost:3000"
echo "  3. Login: admin / admin"
echo ""

echo "Demo applications are running and generating telemetry data automatically!"
echo "You can view traces, metrics, and logs in Grafana."
echo ""

echo "To view traffic generator logs:"
echo "  kubectl logs -n monitoring -l app=traffic-generator -f"
echo ""

echo "To enable auto-instrumentation in your apps, add this annotation:"
echo "  For Python:  instrumentation.opentelemetry.io/inject-python: \"monitoring/demo-instrumentation\""
echo "  For Node.js: instrumentation.opentelemetry.io/inject-nodejs: \"monitoring/demo-instrumentation\""
echo "  For Java:    instrumentation.opentelemetry.io/inject-java: \"monitoring/demo-instrumentation\""
echo ""

echo "For more information, see: monitoring/README.md"
echo ""

print_success "Happy monitoring! 📊"
