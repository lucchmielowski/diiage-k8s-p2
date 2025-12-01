# Kubernetes Monitoring with OpenTelemetry

This directory contains a complete monitoring stack for teaching Kubernetes observability with OpenTelemetry, including automatic sidecar injection, distributed tracing, and metrics collection.

## 📚 Table of Contents

- [Prerequisite Knowledge](#prerequisite-knowledge)
- [Architecture Overview](#architecture-overview)
- [Components](#components)
- [Prerequisites](#prerequisites)
- [Installation Guide](#installation-guide)
- [Using the Stack](#using-the-stack)
- [Student Exercises](#student-exercises)
- [Troubleshooting](#troubleshooting)

## 📖 Prerequisite Knowledge

Modern observability relies on three complementary pillars that work together to provide a comprehensive view of your system's health and behavior. Each pillar serves a specific purpose and answers different questions about your system.

### Metrics

Metrics are quantitative measurements of system behavior collected over time. They provide numerical data points that can be aggregated, analyzed, and visualized to understand trends and patterns. Examples include CPU usage, memory consumption, request rates, error counts, and response times.

**What they tell you:** Metrics answer the "what" and "when" questions about your system's health. They show you that something is happening (e.g., high CPU usage, increased error rate) and when it's occurring.

**Use cases:**
- Monitoring system health and performance trends
- Setting up alerts based on thresholds
- Capacity planning and resource optimization
- Creating dashboards for real-time monitoring

**Tools in this stack:** Prometheus collects and stores metrics, Grafana visualizes them.

### Logs

Logs are discrete records of events that occurred in your system at specific points in time. Each log entry typically includes a timestamp, severity level, and detailed contextual information about what happened. Logs capture the story of your application's execution.

**What they tell you:** Logs answer the "what happened" question. They provide detailed context about specific events, errors, and state changes within your application.

**Use cases:**
- Debugging application errors and exceptions
- Auditing user actions and system changes
- Understanding the sequence of events leading to an issue
- Compliance and security monitoring

**Tools in this stack:** OpenTelemetry Collector can receive logs; in production, you would typically add Loki or Elasticsearch for log aggregation and search.

### Traces

Traces follow the complete journey of a request as it flows through your distributed system. A trace consists of multiple spans, where each span represents a unit of work (like a function call or a service-to-service communication). Traces show the relationships between different components and how long each step took.

**What they tell you:** Traces answer the "where" and "why" questions about performance issues. They reveal which service or component is causing slowdowns and show the complete path a request takes through your microservices architecture.

**Use cases:**
- Identifying performance bottlenecks in distributed systems
- Understanding service dependencies and communication patterns
- Debugging issues that span multiple services
- Optimizing request flows and reducing latency

**Tools in this stack:** Tempo stores and queries traces, Grafana visualizes them with service graphs and trace timelines.

### Why Use All Three Together?

Using metrics, logs, and traces together creates a powerful observability strategy:

1. **Metrics** alert you that there's a problem (e.g., high error rate)
2. **Logs** provide context about what went wrong (e.g., specific error messages)
3. **Traces** help you pinpoint exactly where in your distributed system the issue originated (e.g., which service is slow)

This holistic approach is essential for understanding and debugging complex microservices architectures in Kubernetes, where a single user request might touch dozens of services.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐      Auto-Instrumentation             │
│  │  Your App Pod    │◄────────────────────────────┐         │
│  ├──────────────────┤                             │         │
│  │ OTel Sidecar     │  Injected by                │         │
│  │ (auto-injected)  │  OpenTelemetry Operator     │         │
│  └────────┬─────────┘                             │         │
│           │ OTLP (traces, metrics, logs)          │         │
│           │                                       │         │
│           ▼                                       │         │
│  ┌─────────────────────────────────────┐          │         │
│  │   OpenTelemetry Collector           │          │         │
│  │   - Receives: OTLP (gRPC/HTTP)      │          │         │
│  │   - Processes: Batch, Filter        │          │         │
│  │   - Exports: Tempo, Prometheus      │          │         │
│  └──────┬──────────────────┬───────────┘          │         │
│         │                  │                      │         │
│         │ Traces           │ Metrics              │         │
│         ▼                  ▼                      │         │
│  ┌──────────────┐   ┌──────────────┐              │         │
│  │    Tempo     │   │  Prometheus  │              │         │
│  │  (Tracing)   │   │  (Metrics)   │              │         │
│  └──────┬───────┘   └──────┬───────┘              │         │
│         │                  │                      │         │
│         └────────┬─────────┘                      │         │
│                  │                                │         │
│                  ▼                                │         │
│         ┌─────────────────┐                       │         │
│         │    Grafana      │                       │         │
│         │ (Visualization) │                       │         │
│         └─────────────────┘                       │         │
│                                                   │         │
│         ┌─────────────────────────────────────────┘         │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────────────────────────┐                       │
│  │  OpenTelemetry Operator          │                       │
│  │  - Manages OTel Collector CRD    │                       │
│  │  - Auto-instrumentation injection│                       │
│  └──────────────────────────────────┘                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🧩 Components

### 1. **OpenTelemetry Operator**
- Manages OpenTelemetry Collector deployments
- Automatically injects instrumentation sidecars into pods
- Supports Python, Java, Node.js, .NET auto-instrumentation

### 2. **OpenTelemetry Collector**
- Receives telemetry data via OTLP (gRPC and HTTP)
- Processes and batches data
- Exports traces to Tempo and metrics to Prometheus

### 3. **Tempo**
- Distributed tracing backend
- Stores and queries traces
- Integrated with Grafana for visualization

### 4. **Prometheus**
- Time-series metrics database
- Scrapes metrics from applications and Kubernetes
- Receives metrics from OpenTelemetry Collector

### 5. **Grafana**
- Unified visualization platform
- Pre-configured with Prometheus and Tempo data sources
- Includes example dashboards

## ✅ Prerequisites

- Kubernetes cluster (v1.24+)
- `kubectl` configured to access your cluster
- `helm` (v3.0+) installed
- Basic understanding of Kubernetes and Helm concepts

## 📥 Installation Guide

### Option 1: Automated Installation (Recommended)

The easiest way to install the entire monitoring stack:

```bash
cd monitoring
chmod +x install.sh
./install.sh
```

This script will:
1. Add required Helm repositories
2. Install cert-manager (for OpenTelemetry Operator webhooks)
3. Install OpenTelemetry Operator
4. Deploy all monitoring components via Helm (Tempo, Prometheus, Grafana, OpenTelemetry Collector)
5. Create the Instrumentation resource

**After installation**, access Grafana:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Open http://localhost:3000 (admin/admin)

---

### Option 2: Manual Installation with Helm

#### Step 1: Add Helm Repositories

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

#### Step 2: Install cert-manager

cert-manager is required for the OpenTelemetry Operator webhooks.

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager \
  deployment/cert-manager-webhook \
  deployment/cert-manager-cainjector \
  -n cert-manager
```

#### Step 3: Install OpenTelemetry Operator

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.91.0/opentelemetry-operator.yaml

# Wait for the operator to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/opentelemetry-operator-controller-manager \
  -n opentelemetry-operator-system
```

#### Step 4: Create monitoring namespace

```bash
kubectl apply -f namespace.yaml
```

#### Step 5: Deploy Monitoring Stack via Helm

**Install Tempo:**

```bash
helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  --values tempo/values.yaml \
  --wait
```

**Install Prometheus:**

```bash
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --values prometheus/values.yaml \
  --wait
```

**Install Grafana:**

```bash
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values grafana/values.yaml \
  --wait
```

**Install OpenTelemetry Collector:**

```bash
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --values opentelemetry-collector/values.yaml \
  --wait
```

#### Step 6: Create Instrumentation Resource

This resource defines how applications should be auto-instrumented.

```bash
kubectl apply -f demo-instrumented/instrumentation.yaml
```

#### Step 7: Deploy Demo Applications (Optional)

Deploy example applications with auto-instrumentation:

```bash
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml
```

This deploys three demo apps:
- **demo-python-app**: Python HTTP server with auto-instrumentation
- **demo-nodejs-app**: Node.js HTTP server with auto-instrumentation
- **demo-java-app**: Spring Boot app with auto-instrumentation

#### Step 8: Access the Stack

**Port-forward Grafana:**

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Access Grafana at: http://localhost:3000
- Username: `admin`
- Password: `admin`

**Port-forward Prometheus (optional):**

```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

Access Prometheus at: http://localhost:9090

---

### Customizing Helm Deployments

All Helm values files are located in their respective component directories:
- `grafana/values.yaml` - Grafana configuration
- `prometheus/values.yaml` - Prometheus configuration
- `tempo/values.yaml` - Tempo configuration
- `opentelemetry-collector/values.yaml` - Collector configuration

You can customize these files to adjust:
- Resource limits and requests
- Storage persistence
- Retention policies
- Scrape intervals
- Data source configurations

## 🎯 Using the Stack

### How to Enable Auto-Instrumentation

To enable auto-instrumentation for your applications, add annotations to your Pod spec:

#### Python Application

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-python-app
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-python: "monitoring/demo-instrumentation"
    spec:
      containers:
      - name: app
        image: my-python-app:latest
        env:
        - name: OTEL_SERVICE_NAME
          value: my-python-app
```

#### Node.js Application

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-nodejs: "monitoring/demo-instrumentation"
```

#### Java Application

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-java: "monitoring/demo-instrumentation"
```

#### .NET Application

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-dotnet: "monitoring/demo-instrumentation"
```

### Enable Prometheus Scraping

Add these annotations to enable Prometheus to scrape metrics from your pods:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

### Viewing Traces in Grafana

1. Open Grafana (http://localhost:3000)
2. Navigate to **Explore** (compass icon)
3. Select **Tempo** as the data source
4. Use the **Search** tab to find traces
5. Filter by service name, operation, tags, etc.

### Viewing Metrics in Grafana

1. In Grafana, navigate to **Explore**
2. Select **Prometheus** as the data source
3. Use PromQL queries, for example:
   - `rate(http_requests_total[5m])` - HTTP request rate
   - `otelcol_receiver_accepted_spans` - Spans received by collector
   - `up` - Service availability

## 🎓 Student Exercises

### Exercise 1: Verify the Installation

**Objective:** Ensure all components are running correctly.

**Tasks:**
1. List all pods in the `monitoring` namespace
2. Check that all deployments are ready
3. Verify the OpenTelemetry Collector is receiving data

**Commands:**
```bash
kubectl get pods -n monitoring
kubectl get deployments -n monitoring
kubectl logs -n monitoring deployment/otel-collector-collector -f
```

**Expected Results:**
- All pods should be in `Running` state
- All deployments should show `READY 1/1`
- Collector logs should show no errors

---

### Exercise 2: Deploy an Instrumented Application

**Objective:** Deploy your first auto-instrumented application.

**Tasks:**
1. Deploy the Python demo app
2. Verify the sidecar was injected
3. Generate some traffic
4. Find traces in Grafana

**Commands:**
```bash
# Deploy
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml

# Check if sidecar was injected
kubectl get pod -n monitoring -l app=demo-python-app -o yaml | grep -A 5 "initContainers"

# Generate traffic
kubectl port-forward -n monitoring svc/demo-python-app 8080:8080
# In another terminal:
for i in {1..20}; do curl http://localhost:8080; sleep 1; done

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 and explore traces
```

**Questions:**
- How many containers are in the pod after injection?
- What traces do you see in Tempo?
- What metrics appear in Prometheus?

---

### Exercise 3: Add Instrumentation to Existing Apps

**Objective:** Add auto-instrumentation to the existing demo-frontend app.

**Tasks:**
1. Copy the `demo-frontend` Helm chart
2. Add the instrumentation annotation
3. Deploy and verify traces appear

**Hint:** Add this to the deployment template metadata:
```yaml
annotations:
  instrumentation.opentelemetry.io/inject-python: "monitoring/demo-instrumentation"
```

---

### Exercise 4: Create a Custom Dashboard

**Objective:** Build a Grafana dashboard for your application.

**Tasks:**
1. In Grafana, create a new dashboard
2. Add a panel showing request rate
3. Add a panel showing error rate
4. Add a panel showing request duration (p95, p99)

**Example PromQL queries:**
```promql
# Request rate
rate(http_server_requests_total[5m])

# Error rate
rate(http_server_requests_total{status=~"5.."}[5m])

# Request duration p95
histogram_quantile(0.95, rate(http_server_duration_bucket[5m]))
```

---

### Exercise 5: Trace a Distributed Request

**Objective:** Understand distributed tracing across services.

**Tasks:**
1. Deploy both `demo-frontend` and `demo-backend` with instrumentation
2. Make a request that goes frontend → backend
3. Find the distributed trace in Tempo
4. Analyze the trace spans

**Questions:**
- How many spans are in the trace?
- What's the total request duration?
- Where is most time spent?

---

### Exercise 6: Investigate a Performance Issue

**Objective:** Use observability tools to debug a slow service.

**Scenario:** One of your services is responding slowly.

**Tasks:**
1. Find slow traces in Tempo (duration > 1s)
2. Identify which span is taking the most time
3. Correlate with metrics in Prometheus
4. Propose a solution

---

### Exercise 7: Set Up Alerts (Advanced)

**Objective:** Create a Prometheus alert for high error rates.

**Tasks:**
1. Create a PrometheusRule resource
2. Define an alert for error rate > 5%
3. Test the alert by generating errors

**Example:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: monitoring
spec:
  groups:
  - name: app
    rules:
    - alert: HighErrorRate
      expr: rate(http_server_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      annotations:
        summary: "High error rate detected"
```

---

### Exercise 8: Customize the Instrumentation

**Objective:** Modify the Instrumentation resource to change sampling.

**Tasks:**
1. Edit the `instrumentation.yaml`
2. Change sampler from `always_on` to `traceidratio`
3. Set sampling rate to 50%
4. Apply and observe the difference

**Hint:**
```yaml
sampler:
  type: traceidratio
  argument: "0.5"
```

## 🐛 Troubleshooting

### Helm Release Issues

**List all Helm releases:**
```bash
helm list -n monitoring
```

**Check Helm release status:**
```bash
helm status <release-name> -n monitoring
# Examples: grafana, prometheus, tempo, otel-collector
```

**Get Helm release values:**
```bash
helm get values <release-name> -n monitoring
```

**Rollback a failed upgrade:**
```bash
helm rollback <release-name> -n monitoring
```

**Uninstall and reinstall:**
```bash
helm uninstall <release-name> -n monitoring
helm upgrade --install <release-name> <chart> --namespace monitoring --values <values-file> --wait
```

### Pods not starting

**Check pod status:**
```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

**Check Helm deployment status:**
```bash
kubectl get deployments -n monitoring
helm status grafana -n monitoring
helm status prometheus -n monitoring
helm status tempo -n monitoring
helm status otel-collector -n monitoring
```

### No traces appearing

**Check collector logs:**
```bash
# Note: Helm deployment name may differ
kubectl logs -n monitoring deployment/otel-collector-opentelemetry-collector -f
```

**Verify instrumentation:**
```bash
kubectl get instrumentation -n monitoring
kubectl describe pod <app-pod> -n monitoring
```

**Common issues:**
- Annotation format is wrong (must be `namespace/instrumentation-name`)
- Application language not supported for auto-instrumentation
- Network connectivity issues to collector
- Service names changed with Helm (e.g., `prometheus-server` instead of `prometheus`)

### Grafana not showing data

**Check data source configuration:**
1. Grafana → Configuration → Data Sources
2. Test connection to Prometheus and Tempo
3. Verify URLs are correct (note Helm service names):
   - Prometheus: `http://prometheus-server.monitoring.svc.cluster.local:80`
   - Tempo: `http://tempo.monitoring.svc.cluster.local:3200`

**Reconfigure datasources via Helm:**
```bash
# Edit grafana/values.yaml datasources section
# Then upgrade the release
helm upgrade grafana grafana/grafana -n monitoring --values grafana/values.yaml
```

### High resource usage

**Reduce retention in Prometheus:**

Edit `prometheus/values.yaml`:
```yaml
server:
  retention: "1d"  # Instead of 7d
```

Apply changes:
```bash
helm upgrade prometheus prometheus-community/prometheus -n monitoring --values prometheus/values.yaml
```

**Reduce retention in Tempo:**

Edit `tempo/values.yaml`:
```yaml
tempo:
  config: |
    compactor:
      compaction:
        block_retention: 24h  # Instead of 48h
```

Apply changes:
```bash
helm upgrade tempo grafana/tempo -n monitoring --values tempo/values.yaml
```

**Adjust sampling:**

Edit `demo-instrumented/instrumentation.yaml`:
```yaml
sampler:
  type: traceidratio
  argument: "0.1"  # Sample only 10% of traces
```

Apply changes:
```bash
kubectl apply -f demo-instrumented/instrumentation.yaml
```

### Configuration Changes Not Applied

If you modify a values file and changes don't appear:

```bash
# Upgrade the Helm release with new values
helm upgrade <release-name> <chart> -n monitoring --values <values-file>

# Force recreation of pods
helm upgrade <release-name> <chart> -n monitoring --values <values-file> --force

# Verify the new configuration
helm get values <release-name> -n monitoring
```

## 📖 Additional Resources

### OpenTelemetry Documentation
- [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Auto-instrumentation](https://opentelemetry.io/docs/instrumentation/)

### Observability Tools
- [Prometheus](https://prometheus.io/docs/)
- [Grafana Tempo](https://grafana.com/docs/tempo/latest/)
- [Grafana](https://grafana.com/docs/grafana/latest/)

### PromQL Resources
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

## 🚀 Next Steps

- Integrate with Loki for log aggregation
- Add alerting with AlertManager
- Explore service mesh (Istio/Linkerd) integration
- Set up long-term storage (S3, GCS)
- Implement SLOs and error budgets
