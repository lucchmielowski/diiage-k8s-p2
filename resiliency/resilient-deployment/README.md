# Resilient Deployment Example

A production-ready Kubernetes deployment demonstrating comprehensive reliability features and best practices.

## 📋 Overview

This example showcases a resilient application deployment incorporating all the reliability principles from the resiliency guide:

- **High Availability** - Multiple replicas with anti-affinity
- **Health Checks** - Startup, liveness, and readiness probes
- **Resource Management** - CPU/memory requests and limits
- **Graceful Shutdown** - Proper termination handling
- **Autoscaling** - Horizontal Pod Autoscaler (HPA)
- **Disruption Protection** - PodDisruptionBudget (PDB)
- **Zero-downtime Deployments** - Rolling update strategy
- **Security** - Non-root user, read-only filesystem, dropped capabilities

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│              Service (resilient-app)                │
│                  LoadBalancer                       │
└────────────┬───────────┬──────────────┬─────────────┘
             │           │              │
        ┌────▼───┐  ┌────▼───┐    ┌────▼───┐
        │ Pod 1  │  │ Pod 2  │    │ Pod 3  │
        │        │  │        │    │        │
        │ Ready  │  │ Ready  │    │ Ready  │
        └────────┘  └────────┘    └────────┘
             │           │              │
        ┌────▼───────────▼──────────────▼────┐
        │  HPA (scales 3-10 based on load)   │
        └─────────────────────────────────────┘
             │
        ┌────▼────────────────────────────────┐
        │  PDB (minAvailable: 2)              │
        │  Ensures availability during drain  │
        └─────────────────────────────────────┘
```

## 📦 Components

### 1. Deployment (`deployment.yaml`)

**Key Features:**

#### High Availability
```yaml
replicas: 3
```
- Minimum 3 replicas for redundancy
- Can handle 1 pod failure without degradation
- Distributes load across multiple instances

#### Pod Anti-Affinity
```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution
```
- Spreads pods across different nodes
- Reduces single point of failure
- Improves resilience to node failures

#### Health Probes

**Startup Probe** (`/healthz`)
- Protects slow-starting applications
- Allows up to 150 seconds for startup (30 failures × 5s)
- Prevents premature pod restarts

**Liveness Probe** (`/healthz`)
- Detects deadlocked or hung applications
- Restarts pod after 3 consecutive failures
- Simple check (< 1s response time)

**Readiness Probe** (`/ready`)
- Determines if pod can serve traffic
- Checks dependencies (DB, cache, external APIs)
- Removes from service endpoints if unhealthy

#### Resource Management
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```
- **Requests**: Guaranteed resources for scheduling
- **Limits**: Maximum resources (CPU throttled, memory causes OOMKill)
- **QoS Class**: Burstable (good balance for most apps)

#### Graceful Shutdown
```yaml
terminationGracePeriodSeconds: 30
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 5"]
```
- 5 second sleep allows load balancer updates
- Application has 25 seconds to finish in-flight requests
- Prevents connection errors during pod termination

#### Rolling Update Strategy
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```
- Zero-downtime deployments
- Always maintains minimum capacity
- Adds new pods before removing old ones

### 2. Service (`service.yaml`)

**Features:**
- ClusterIP type for internal communication
- Simple load balancing across pods
- Automatic endpoint updates based on readiness probes

### 3. PodDisruptionBudget (`poddisruptionbudget.yaml`)

**Purpose:** Ensures availability during voluntary disruptions

```yaml
minAvailable: 2
```

**Protects against:**
- Node drains during maintenance
- Cluster upgrades
- Manual pod evictions
- Zone evacuations

**How it works:**
- Kubernetes won't drain a node if it would violate the PDB
- Ensures at least 2 pods are always running
- With 3 replicas, only 1 pod can be disrupted at a time

### 4. HorizontalPodAutoscaler (`hpa.yaml`)

**Scaling Strategy:**
```yaml
minReplicas: 3
maxReplicas: 10
metrics:
  - cpu: 70%
  - memory: 80%
```

**Scaling Behavior:**

**Scale Up** (Fast)
- Reacts immediately (0s stabilization)
- Can double pods every 15 seconds
- Quick response to traffic spikes

**Scale Down** (Slow)
- 5 minute stabilization window
- Maximum 50% reduction per minute
- Prevents flapping

**Example Scaling:**
```
Load increases:
3 pods @ 80% CPU → Scale to 5 pods → Scale to 8 pods
            ▲              ▲              ▲
          15s later    15s later     15s later

Load decreases:
8 pods @ 30% CPU → Wait 5min → Scale to 6 pods → Wait 5min → Scale to 4 pods
```

## 🚀 Deployment

### Prerequisites

- Kubernetes cluster (1.19+)
- `kubectl` configured
- Metrics Server installed (for HPA)

### Install Metrics Server (if needed)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Deploy Application

```bash
# Deploy all components
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f poddisruptionbudget.yaml
kubectl apply -f hpa.yaml

# Or deploy all at once
kubectl apply -f .
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -l app=resilient-app

# Check service
kubectl get svc resilient-app

# Check PDB status
kubectl get pdb resilient-app-pdb

# Check HPA status
kubectl get hpa resilient-app-hpa

# Watch autoscaling
kubectl get hpa resilient-app-hpa --watch
```

## 🔍 Testing Resilience

### 1. Test Health Checks

```bash
# Watch pod status
kubectl get pods -l app=resilient-app -w

# Delete a pod to test restart
kubectl delete pod -l app=resilient-app --field-selector=status.phase=Running | head -1

# Observe:
# - New pod starts immediately
# - Service continues without interruption
# - Startup probe allows time to initialize
# - Readiness probe controls traffic routing
```

### 2. Test PodDisruptionBudget

```bash
# Try to drain a node
kubectl drain <node-name> --ignore-daemonsets

# Observe:
# - Kubernetes respects minAvailable: 2
# - Waits for new pod to be ready before draining next
# - Ensures continuous availability
```

### 3. Test Autoscaling

```bash
# Generate load (example with Apache Bench)
kubectl run -it --rm load-generator --image=busybox --restart=Never -- /bin/sh

# Inside the pod:
while true; do wget -q -O- http://resilient-app; done

# In another terminal, watch scaling
kubectl get hpa resilient-app-hpa --watch

# Observe:
# - CPU utilization increases
# - HPA scales up pods quickly
# - When load stops, scales down slowly (5min wait)
```

### 4. Test Graceful Shutdown

```bash
# Start monitoring service
kubectl run -it --rm monitor --image=nicolaka/netshoot --restart=Never -- bash
# Inside: watch -n 1 curl -s http://resilient-app

# In another terminal, trigger rolling update
kubectl set image deployment/resilient-app app=nginx:1.25-alpine

# Observe:
# - Zero failed requests
# - Smooth transition between versions
# - Graceful termination prevents connection errors
```

### 5. Test Rolling Updates

```bash
# Update image
kubectl set image deployment/resilient-app app=nginx:1.26-alpine

# Watch rollout
kubectl rollout status deployment/resilient-app

# Observe:
# - New pods created before old ones terminate
# - maxUnavailable: 0 ensures capacity maintained
# - Service never degraded
```

## 🎯 Customization

### Adjust for Your Application

#### 1. Update Image and Ports
```yaml
image: your-registry/your-app:v1.0.0
ports:
  - containerPort: 3000  # Your app port
```

#### 2. Configure Health Endpoints

Your application should implement:
- `/healthz` - Simple liveness check (return 200 OK)
- `/ready` - Readiness check (verify dependencies)

Example implementation:
```go
// /healthz - Always return 200 if process is alive
http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("OK"))
})

// /ready - Check dependencies
http.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
    if dbReady() && cacheReady() {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("Ready"))
    } else {
        w.WriteHeader(http.StatusServiceUnavailable)
        w.Write([]byte("Not Ready"))
    }
})
```

#### 3. Adjust Resource Limits

Based on your application's needs:
```yaml
resources:
  requests:
    cpu: 500m      # Heavy CPU app
    memory: 1Gi    # Memory-intensive app
  limits:
    cpu: 2000m
    memory: 2Gi
```

#### 4. Tune Autoscaling

```yaml
minReplicas: 5           # Higher baseline for critical apps
maxReplicas: 50          # Allow more scaling for variable load
metrics:
  - cpu: 60%             # More aggressive scaling
  - memory: 70%
```

#### 5. Adjust PDB for Replica Count

```yaml
# For 5 replicas, ensure 4 are available
minAvailable: 4

# Or use percentage
minAvailable: 80%  # 80% of pods must be available
```

## 🛡️ Best Practices Applied

✅ **Never run as root** - `runAsNonRoot: true`  
✅ **Drop all capabilities** - `capabilities.drop: [ALL]`  
✅ **Read-only root filesystem** - `readOnlyRootFilesystem: true`  
✅ **Resource limits set** - Prevents resource exhaustion  
✅ **Health checks configured** - All three probe types  
✅ **Graceful shutdown** - `terminationGracePeriodSeconds: 30`  
✅ **Anti-affinity** - Spreads pods across nodes  
✅ **PDB defined** - Protects against disruptions  
✅ **HPA configured** - Automatic scaling  
✅ **Rolling updates** - Zero-downtime deployments  

## 📚 Related Concepts

- **Circuit Breakers** - Implement in your application code or service mesh
- **Rate Limiting** - Use API Gateway or service mesh
- **Chaos Engineering** - Test with [chaos-mesh examples](../chaos-mesh/)
- **Observability** - Set up monitoring stack in [monitoring/](../../monitoring/)

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -f .

# Or individually
kubectl delete deployment resilient-app
kubectl delete service resilient-app
kubectl delete pdb resilient-app-pdb
kubectl delete hpa resilient-app-hpa
```

## 📖 Additional Resources

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

---

**Remember:** This is a template. Adapt it to your specific application requirements, load patterns, and SLOs!
