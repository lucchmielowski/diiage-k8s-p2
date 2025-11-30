# Quick Start Guide - Monitoring Stack

## 🚀 5-Minute Setup

### Option 1: Automated Installation (Recommended)

**Prerequisites:** `kubectl` and `helm` (v3.0+) installed

```bash
cd monitoring
chmod +x install.sh
./install.sh
```

This will install everything automatically via Helm, including:
- All monitoring components (Grafana, Prometheus, Tempo, OpenTelemetry Collector)
- Demo applications (Python, Node.js, Java) with auto-instrumentation
- Traffic generator that continuously calls demo apps to generate telemetry data

When done, access Grafana to view the telemetry:

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Open http://localhost:3000 (admin/admin)

The traffic generator is already running and generating traces, metrics, and logs!

---

### Option 2: Manual Installation with Helm

```bash
# 1. Add Helm repositories
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# 2. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager

# 3. Install OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.91.0/opentelemetry-operator.yaml
kubectl wait --for=condition=available --timeout=300s deployment/opentelemetry-operator-controller-manager -n opentelemetry-operator-system

# 4. Create monitoring namespace
cd monitoring
kubectl apply -f namespace.yaml

# 5. Deploy monitoring stack via Helm
helm upgrade --install tempo grafana/tempo --namespace monitoring --values tempo/values.yaml --wait
helm upgrade --install prometheus prometheus-community/prometheus --namespace monitoring --values prometheus/values.yaml --wait
helm upgrade --install grafana grafana/grafana --namespace monitoring --values grafana/values.yaml --wait
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector --namespace monitoring --values opentelemetry-collector/values.yaml --wait

# 6. Create instrumentation resource
kubectl apply -f demo-instrumented/instrumentation.yaml

# 7. Check everything is ready
kubectl get pods -n monitoring
```

---

## 📊 Verify Installation

```bash
# Check all pods are running
kubectl get pods -n monitoring

# Expected output:
# NAME                                                READY   STATUS    
# grafana-xxxxx                                      1/1     Running
# otel-collector-opentelemetry-collector-xxxxx       1/1     Running
# prometheus-server-xxxxx                            2/2     Running
# tempo-0                                            1/1     Running
# demo-python-app-xxxxx                              1/1     Running
# demo-nodejs-app-xxxxx                              1/1     Running
# demo-java-app-xxxxx                                1/1     Running
# traffic-generator-xxxxx                            1/1     Running
```

Check traffic generator is working:

```bash
# View traffic generator logs
kubectl logs -n monitoring -l app=traffic-generator -f

# You should see output like:
# [2024-11-30 10:00:00] Calling Python app...
# Status: 200
# [2024-11-30 10:00:02] Calling Node.js app...
# Status: 200
# [2024-11-30 10:00:04] Calling Java app...
# Status: 200
```

---

## 🎓 Teaching Flow

### Lesson 1: Deploy First Instrumented App (15 min)

```bash
# Deploy Python demo
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml

# Check sidecar injection
kubectl get pod -n monitoring -l app=demo-python-app -o yaml | grep -A 5 "initContainers"

# Generate traffic
kubectl port-forward -n monitoring svc/demo-python-app 8080:8080
curl http://localhost:8080

# View traces in Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 → Explore → Tempo
```

**Key Concepts:**
- Auto-instrumentation with annotations
- Sidecar injection by OpenTelemetry Operator
- OTLP protocol
- Distributed tracing basics

---

### Lesson 2: Add Instrumentation to Existing App (20 min)

```bash
# Show students how to modify demo-frontend
# Add this annotation to the deployment template:
instrumentation.opentelemetry.io/inject-python: "monitoring/demo-instrumentation"

# Deploy and verify
kubectl get pods -n dev -l app=demo-frontend
```

**Key Concepts:**
- Annotation-based instrumentation
- Cross-namespace instrumentation references
- Trace context propagation

---

### Lesson 3: Explore Traces and Metrics (30 min)

**In Grafana:**

1. **Explore traces**
   - Navigate to Explore → Tempo
   - Search by service name
   - Analyze span durations
   - Understand parent-child relationships

2. **Query metrics**
   - Navigate to Explore → Prometheus
   - Try these queries:
     ```promql
     rate(otelcol_receiver_accepted_spans[5m])
     up{namespace="monitoring"}
     ```

3. **Create dashboard**
   - New Dashboard → Add Panel
   - Add request rate, error rate, latency

**Key Concepts:**
- PromQL basics
- Span analysis
- Service dependency mapping
- RED metrics (Rate, Errors, Duration)

---

### Lesson 4: Distributed Tracing (30 min)

```bash
# Deploy multiple services
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml

# Generate request chain
# Python → Node.js → Java
```

**Key Concepts:**
- Trace IDs and span IDs
- Context propagation
- Service mesh concepts
- Performance bottleneck identification

---

## 🔧 Common Student Questions

### Q: Why do I need an annotation?

A: The annotation tells the OpenTelemetry Operator to inject auto-instrumentation. Without it, you'd need to manually add OpenTelemetry SDK to your code.

### Q: What's the difference between traces and metrics?

A: 
- **Traces**: Show the path of a single request through your system
- **Metrics**: Show aggregated statistics over time (e.g., request rate, CPU usage)

### Q: Can I use this in production?

A: This setup is for learning. For production:
- Use persistent storage (not emptyDir)
- Set up proper retention policies
- Configure sampling (not always_on)
- Add authentication/authorization
- Use Helm charts for easier management

### Q: Why cert-manager?

A: The OpenTelemetry Operator uses webhooks to inject sidecars. Webhooks need TLS certificates, which cert-manager provides automatically.

---

## 🐛 Troubleshooting Guide

### No traces appearing in Tempo

```bash
# Check collector logs
kubectl logs -n monitoring deployment/otel-collector-collector -f

# Check if annotation is correct (must be namespace/name)
kubectl get instrumentation -n monitoring
kubectl describe pod <your-app-pod> -n monitoring
```

### Pod stuck in Init state

```bash
# Check init container logs
kubectl logs <pod-name> -n monitoring -c opentelemetry-auto-instrumentation

# Common issue: Can't pull instrumentation image
# Solution: Check network connectivity
```

### Grafana shows "No data"

```bash
# Test Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090 and verify targets

# Test Tempo
kubectl port-forward -n monitoring svc/tempo 3200:3200
curl http://localhost:3200/ready
```

---

## 📝 Exercises for Students

1. **Basic**: Deploy demo-python-app and find its traces in Grafana
2. **Intermediate**: Add instrumentation to demo-frontend and create a dashboard
3. **Advanced**: Set up distributed tracing between frontend and backend
4. **Expert**: Implement custom sampling rules and create alerting rules

---

## 🔗 Quick Links

- **Full Documentation**: [README.md](README.md)
- **OpenTelemetry Docs**: https://opentelemetry.io/docs/
- **Grafana Tempo**: https://grafana.com/docs/tempo/
- **PromQL Guide**: https://prometheus.io/docs/prometheus/latest/querying/basics/

---

## 📦 What's Included

```
monitoring/
├── install.sh                          # One-command installation
├── README.md                           # Complete documentation
├── QUICK_START.md                      # This file
├── namespace.yaml                      # Monitoring namespace
├── opentelemetry-operator/            # OTel operator installation
│   ├── install-cert-manager.sh
│   └── install-operator.sh
├── opentelemetry-collector/           # Collector configuration
│   └── collector.yaml
├── tempo/                             # Tracing backend
│   └── tempo.yaml
├── prometheus/                        # Metrics backend
│   └── prometheus.yaml
├── grafana/                          # Visualization
│   └── grafana.yaml
├── demo-instrumented/                # Example apps
│   ├── instrumentation.yaml          # Auto-instrumentation config
│   └── demo-app-instrumented.yaml    # Demo applications
└── argocd/                           # GitOps integration
    └── monitoring-app.yaml           # ArgoCD Application
```

---

## 🎯 Learning Path

1. **Day 1**: Install stack, deploy demo apps, view traces
2. **Day 2**: Add instrumentation to existing apps, explore metrics
3. **Day 3**: Build dashboards, understand distributed tracing
4. **Day 4**: Advanced topics: sampling, alerts, custom instrumentation

---

## 💡 Tips for Instructors

- Start with the automated installation to save time
- Use the Python demo first (simplest)
- Show live logs with `kubectl logs -f` during traffic generation
- Use Grafana's Explore feature before building dashboards
- Emphasize the annotation pattern - it's the key to auto-instrumentation
- Compare auto-instrumentation vs manual SDK approach
- Discuss production considerations (sampling, retention, costs)

---

## 🧹 Cleanup

```bash
# Remove demo apps
kubectl delete -f demo-instrumented/demo-app-instrumented.yaml

# Remove monitoring stack
kubectl delete namespace monitoring

# Remove operators (optional)
kubectl delete -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.91.0/opentelemetry-operator.yaml
kubectl delete namespace cert-manager
```

---

**Ready to start?** Run `./install.sh` and you're good to go! 🚀
