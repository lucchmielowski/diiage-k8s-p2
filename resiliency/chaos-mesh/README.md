# Chaos Mesh Examples

Basic examples for chaos engineering with Chaos Mesh on Kubernetes.

## 📋 Prerequisites

- Kubernetes cluster (kind, minikube, or cloud provider)
- `kubectl` configured
- `helm` installed
- Demo applications deployed (optional, for testing)

## 🚀 Installation

Run the installation script:

```bash
chmod +x install-chaos-mesh.sh
./install-chaos-mesh.sh
```

Or install manually:

```bash
# Add Chaos Mesh Helm repo
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Install Chaos Mesh
kubectl create namespace chaos-mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.create=true
```

### Verify Installation

```bash
kubectl get pods -n chaos-mesh
kubectl get crds | grep chaos-mesh
```

### Access Dashboard

```bash
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
```

Open http://localhost:2333 in your browser.

## 📚 Examples

**Note**: Each example is self-contained and creates its own test application pods. You can run any example in isolation without needing existing applications.

### 1. Pod Kill - `examples/pod-kill.yaml`

Creates a test application with 3 replicas and randomly kills one pod.

```bash
kubectl apply -f examples/pod-kill.yaml
```

This will:
1. Create a test application deployment (`test-app-pod-kill`) with 3 replicas
2. Create a service for the application
3. Start a chaos experiment that kills one random pod

**Use case**: Test if your application properly handles pod restarts and if monitoring detects the failure.

**Watch the effect**:
```bash
kubectl get pods -w -l app=test-app-pod-kill
```

**Cleanup**:
```bash
kubectl delete -f examples/pod-kill.yaml
```

### 2. Network Delay - `examples/network-delay.yaml`

Creates a test application and adds 200ms latency (±50ms jitter) to incoming traffic for one pod.

```bash
kubectl apply -f examples/network-delay.yaml
```

This will:
1. Create a test application deployment (`test-app-network-delay`) with 2 replicas
2. Create a service for the application
3. Start a chaos experiment that adds network delay to one pod

**Use case**: Test how your application behaves under network latency and if timeouts are properly configured.

**Test the latency**:
```bash
# Port-forward the service
kubectl port-forward svc/test-app-network-delay 8080:80

# In another terminal, test the latency
for i in {1..10}; do time curl http://localhost:8080; done
```

**Cleanup**:
```bash
kubectl delete -f examples/network-delay.yaml
```

### 3. Pod Failure - `examples/pod-failure.yaml`

Creates a test application with 4 replicas and makes 50% of pods unavailable for 1 minute without deleting them.

```bash
kubectl apply -f examples/pod-failure.yaml
```

This will:
1. Create a test application deployment (`test-app-pod-failure`) with 4 replicas
2. Create a service for the application
3. Start a chaos experiment that makes 50% of pods unavailable

**Use case**: Test if your load balancer properly routes traffic away from failed pods and if you have enough replicas.

**Monitor**:
```bash
kubectl get pods -l app=test-app-pod-failure
kubectl describe pod <pod-name>
# Check the service endpoints
kubectl get endpoints test-app-pod-failure
```

**Cleanup**:
```bash
kubectl delete -f examples/pod-failure.yaml
```

### 4. Stress Test - `examples/stress-test.yaml`

Creates a test application and stresses one pod with high CPU (80% on 2 workers) and memory consumption (256MB).

```bash
kubectl apply -f examples/stress-test.yaml
```

This will:
1. Create a test application deployment (`test-app-stress-test`) with 2 replicas
2. Create a service for the application
3. Start a chaos experiment that stresses one pod with CPU and memory load

**Use case**: Test resource limits, horizontal pod autoscaling, and application performance under stress.

**Monitor resources**:
```bash
kubectl top pods -l app=test-app-stress-test
kubectl get pods -l app=test-app-stress-test -o wide
```

**Cleanup**:
```bash
kubectl delete -f examples/stress-test.yaml
```

## 🔍 Managing Chaos Experiments

### List all experiments

```bash
kubectl get podchaos
kubectl get networkchaos
kubectl get stresschaos
```

### Check experiment status

```bash
kubectl describe podchaos pod-kill-example
```

### Delete an experiment

**Note**: Since each example file contains both the test application and the chaos experiment, deleting the file will remove both:

```bash
# This removes both the test app and the chaos experiment
kubectl delete -f examples/pod-kill.yaml

# Or delete just the chaos experiment (keeps the test app running)
kubectl delete podchaos pod-kill-example

# Or delete just the test app (keeps the chaos experiment, but it won't find targets)
kubectl delete deployment test-app-pod-kill
kubectl delete service test-app-pod-kill
```

### Pause/Resume an experiment

```bash
# Pause
kubectl annotate podchaos pod-kill-example experiment.chaos-mesh.org/pause=true

# Resume
kubectl annotate podchaos pod-kill-example experiment.chaos-mesh.org/pause-
```

## 🎯 Customization Tips

### Change target selector

Modify the `selector` section to target different pods:

```yaml
selector:
  namespaces:
    - your-namespace
  labelSelectors:
    app: your-app
    tier: backend
```

### Change chaos mode

Available modes:
- `one`: Randomly select one pod
- `all`: Select all matching pods
- `fixed`: Select a fixed number of pods
- `fixed-percent`: Select a percentage of pods
- `random-max-percent`: Randomly select up to a percentage

Example:
```yaml
mode: fixed
value: "3"  # Affect exactly 3 pods
```

### Add scheduling

Run chaos experiments on a schedule:

```yaml
scheduler:
  cron: "@every 5m"  # Run every 5 minutes
```

## 🛡️ Safety Recommendations

1. **Start small**: Begin with `mode: one` and short durations
2. **Use labels**: Target specific test environments with label selectors
3. **Monitor**: Always observe the effects with monitoring tools
4. **Test in dev first**: Never run chaos experiments in production without testing
5. **Define scope**: Use namespace isolation for chaos experiments
6. **Set alerts**: Configure alerts to detect when chaos is affecting your SLOs

## 📖 Additional Resources

- [Chaos Mesh Documentation](https://chaos-mesh.org/docs/)
- [Chaos Mesh GitHub](https://github.com/chaos-mesh/chaos-mesh)
- [Principles of Chaos Engineering](https://principlesofchaos.org/)

## 🧹 Cleanup

To completely remove Chaos Mesh:

```bash
helm uninstall chaos-mesh -n chaos-mesh
kubectl delete namespace chaos-mesh
kubectl delete crd $(kubectl get crd | grep chaos-mesh.org | awk '{print $1}')
```
