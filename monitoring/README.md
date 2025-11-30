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
│                      Kubernetes Cluster                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐      Auto-Instrumentation             │
│  │  Your App Pod    │◄────────────────────────────┐         │
│  ├──────────────────┤                              │         │
│  │ OTel Sidecar     │  Injected by                │         │
│  │ (auto-injected)  │  OpenTelemetry Operator     │         │
│  └────────┬─────────┘                              │         │
│           │ OTLP (traces, metrics, logs)           │         │
│           │                                         │         │
│           ▼                                         │         │
│  ┌─────────────────────────────────────┐           │         │
│  │   OpenTelemetry Collector           │           │         │
│  │   - Receives: OTLP (gRPC/HTTP)      │           │         │
│  │   - Processes: Batch, Filter        │           │         │
│  │   - Exports: Tempo, Prometheus      │           │         │
│  └──────┬──────────────────┬───────────┘           │         │
│         │                  │                        │         │
│         │ Traces           │ Metrics                │         │
│         ▼                  ▼                        │         │
│  ┌──────────────┐   ┌──────────────┐              │         │
│  │    Tempo     │   │  Prometheus  │              │         │
│  │  (Tracing)   │   │  (Metrics)   │              │         │
│  └──────┬───────┘   └──────┬───────┘              │         │
│         │                  │                        │         │
│         └────────┬─────────┘                        │         │
│                  │                                  │         │
│                  ▼                                  │         │
│         ┌─────────────────┐                        │         │
│         │    Grafana      │                        │         │
│         │ (Visualization) │                        │         │
│         └─────────────────┘                        │         │
│                                                     │         │
│         ┌──────────────────────────────────────────┘         │
│         │                                                     │
│         ▼                                                     │
│  ┌──────────────────────────────────┐                        │
│  │  OpenTelemetry Operator          │                        │
│  │  - Manages OTel Collector CRD    │                        │
│  │  - Auto-instrumentation injection│                        │
│  └──────────────────────────────────┘                        │
│                                                               │
└───────────────────────────────────────────────────────────────┘
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
- Basic understanding of Kubernetes concepts

## 📥 Installation Guide

### Step 1: Install cert-manager

cert-manager is required for the OpenTelemetry Operator webhooks.

```bash
cd monitoring/opentelemetry-operator
chmod +x install-cert-manager.sh
./install-cert-manager.sh
```

**What it does:**
- Installs cert-manager v1.13.2
- Waits for all cert-manager components to be ready

### Step 2: Install OpenTelemetry Operator

```bash
chmod +x install-operator.sh
./install-operator.sh
```

**What it does:**
- Creates the `monitoring` namespace
- Installs OpenTelemetry Operator v0.91.0
- Operator runs in `opentelemetry-operator-system` namespace

### Step 3: Deploy the Monitoring Stack

```bash
# From the monitoring directory
kubectl apply -f namespace.yaml
kubectl apply -f tempo/tempo.yaml
kubectl apply -f prometheus/prometheus.yaml
kubectl apply -f grafana/grafana.yaml
kubectl apply -f opentelemetry-collector/collector.yaml
```

**Wait for all components to be ready:**

```bash
kubectl wait --for=condition=available --timeout=300s \
  deployment/tempo \
  deployment/prometheus \
  deployment/grafana \
  -n monitoring

kubectl wait --for=condition=available --timeout=300s \
  deployment/otel-collector-collector \
  -n monitoring
```

### Step 4: Create Instrumentation Resource

This resource defines how applications should be auto-instrumented.

```bash
kubectl apply -f demo-instrumented/instrumentation.yaml
```

### Step 5: Deploy Demo Applications (Optional)

Deploy example applications with auto-instrumentation:

```bash
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml
```

This deploys three demo apps:
- **demo-python-app**: Python HTTP server with auto-instrumentation
- **demo-nodejs-app**: Node.js HTTP server with auto-instrumentation
- **demo-java-app**: Spring Boot app with auto-instrumentation

### Step 6: Access the Stack

**Port-forward Grafana:**

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Access Grafana at: http://localhost:3000
- Username: `admin`
- Password: `admin`

**Port-forward Prometheus (optional):**

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Access Prometheus at: http://localhost:9090

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

### Pods not starting

**Check pod status:**
```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

### No traces appearing

**Check collector logs:**
```bash
kubectl logs -n monitoring deployment/otel-collector-collector -f
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

### Grafana not showing data

**Check data source configuration:**
1. Grafana → Configuration → Data Sources
2. Test connection to Prometheus and Tempo
3. Verify URLs are correct:
   - Prometheus: `http://prometheus.monitoring.svc.cluster.local:9090`
   - Tempo: `http://tempo.monitoring.svc.cluster.local:3200`

### High resource usage

**Reduce retention:**
```yaml
# In prometheus.yaml
--storage.tsdb.retention.time=1d  # Instead of 7d

# In tempo.yaml
block_retention: 24h  # Instead of 48h
```

**Adjust sampling:**
```yaml
# In instrumentation.yaml
sampler:
  type: traceidratio
  argument: "0.1"  # Sample only 10% of traces
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

## 🎯 Learning Objectives

By completing these exercises, students will learn:

1. **OpenTelemetry Fundamentals**
   - What is observability (traces, metrics, logs)
   - How OpenTelemetry standardizes telemetry
   - Auto-instrumentation vs manual instrumentation

2. **Distributed Tracing**
   - How traces flow through distributed systems
   - Understanding spans, trace context, and propagation
   - Debugging with distributed traces

3. **Metrics Collection**
   - Prometheus architecture and data model
   - PromQL query language
   - Service-level indicators (SLIs)

4. **Visualization**
   - Building meaningful dashboards
   - Correlating metrics and traces
   - Creating actionable alerts

5. **Kubernetes Observability**
   - Observing containerized applications
   - Service mesh integration concepts
   - Best practices for production monitoring

## 🚀 Next Steps

- Integrate with Loki for log aggregation
- Add alerting with AlertManager
- Explore service mesh (Istio/Linkerd) integration
- Set up long-term storage (S3, GCS)
- Implement SLOs and error budgets
