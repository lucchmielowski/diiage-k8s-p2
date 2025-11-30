# Archived Kubernetes Manifests

## Why These Files Are Archived

This directory contains the original custom Kubernetes manifests that were previously used to deploy the monitoring stack components. As of the latest update, **the monitoring stack now uses Helm charts** for deployment instead of custom manifests.

## What Changed

### Before (Custom Manifests)
- Manual deployment using `kubectl apply -f <file>.yaml`
- Required maintaining custom YAML configurations
- Difficult to upgrade and manage versions
- No standardized configuration management

### After (Helm Charts)
- Standardized deployment using official Helm charts
- Easy version management and upgrades with `helm upgrade`
- Values-based configuration in `values.yaml` files
- Better community support and best practices

## Archived Files

- **grafana.yaml** - Original Grafana deployment manifest
- **prometheus.yaml** - Original Prometheus deployment manifest  
- **tempo.yaml** - Original Tempo deployment manifest

## How to Use Helm Charts Now

### Installation

All components are now installed via Helm:

```bash
# Automated installation
./install.sh

# Or manual Helm installation
helm upgrade --install grafana grafana/grafana --namespace monitoring --values grafana/values.yaml
helm upgrade --install prometheus prometheus-community/prometheus --namespace monitoring --values prometheus/values.yaml
helm upgrade --install tempo grafana/tempo --namespace monitoring --values tempo/values.yaml
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector --namespace monitoring --values opentelemetry-collector/values.yaml
```

### Configuration

Instead of editing YAML manifests directly, customize the Helm values files:
- `../grafana/values.yaml`
- `../prometheus/values.yaml`
- `../tempo/values.yaml`
- `../opentelemetry-collector/values.yaml`

### Benefits

1. **Easy upgrades**: `helm upgrade <release> <chart> --reuse-values`
2. **Rollback support**: `helm rollback <release> <revision>`
3. **Version tracking**: `helm list -n monitoring`
4. **Community support**: Official charts are well-maintained
5. **Standardization**: Consistent deployment patterns

## Notes

- The OpenTelemetry Collector still uses the operator CRD (`opentelemetry-collector/collector.yaml`) in addition to Helm
- These archived manifests are kept for reference only
- For production deployments, always use the Helm charts

## Migration Guide

If you have an existing deployment with the old manifests:

```bash
# 1. Remove old deployments
kubectl delete -f grafana.yaml
kubectl delete -f prometheus.yaml
kubectl delete -f tempo.yaml

# 2. Install with Helm
cd ../..
./install.sh
```

For more information, see the main [README.md](../../README.md) and [QUICK_START.md](../../QUICK_START.md).
