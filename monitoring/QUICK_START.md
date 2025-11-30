# Quick Start Guide - Monitoring Stack

## 🚀 5-Minute Setup

### Option 1: Automated Installation (Recommended)

```bash
cd monitoring
./install.sh
```

This will install everything automatically. When done:

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Deploy demo apps (optional)
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml
```

Open http://localhost:3000 (admin/admin)

---

### Option 2: Manual Installation

```bash
# 1. Install cert-manager
cd monitoring/opentelemetry-operator
./install-cert-manager.sh

# 2. Install OpenTelemetry Operator
./install-operator.sh

# 3. Deploy monitoring stack
cd ..
kubectl apply -f namespace.yaml
kubectl apply -f tempo/tempo.yaml
kubectl apply -f prometheus/prometheus.yaml
kubectl apply -f grafana/grafana.yaml
kubectl apply -f opentelemetry-collector/collector.yaml

# 4. Create instrumentation resource
kubectl apply -f demo-instrumented/instrumentation.yaml

# 5. Wait for everything to be ready
kubectl get pods -n monitoring -w
```

---

## 📊 Verify Installation

```bash
# Check all pods are running
kubectl get pods -n monitoring

# Expected output:
# NAME                                      READY   STATUS    
# grafana-xxxxx                            1/1     Running
# otel-collector-collector-xxxxx           1/1     Running
# prometheus-xxxxx                         1/1     Running
# tempo-xxxxx                              1/1     Running
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
