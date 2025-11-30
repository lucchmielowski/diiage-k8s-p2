#!/bin/bash
set -e

echo "Installing OpenTelemetry Operator..."

# Create monitoring namespace if it doesn't exist
kubectl apply -f ../namespace.yaml

# Install OpenTelemetry Operator using the official manifest
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.91.0/opentelemetry-operator.yaml

echo "Waiting for OpenTelemetry Operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/opentelemetry-operator-controller-manager -n opentelemetry-operator-system

echo "OpenTelemetry Operator installed successfully!"
echo ""
echo "Note: The operator is installed in 'opentelemetry-operator-system' namespace"
echo "You can now create OpenTelemetryCollector and Instrumentation resources in your application namespaces"
