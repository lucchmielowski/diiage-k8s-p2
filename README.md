# E-Commerce Demo - Kubernetes Training

Stack complète pour enseigner Authorization (Kyverno), Resilience & Observability, et Advanced Kubernetes Operations.

## Architecture

```
┌──────────┐      ┌──────┐      ┌─────────┐      ┌──────────────┐
│ frontend │─────▶│ cart │─────▶│ payment │─────▶│ notification │
│  :8080   │      │ :8081│      │  :8082  │      │    :8083     │
└──────────┘      └──────┘      └─────────┘      └──────────────┘
     │                │              │                    │
     └────────────────┴──────────────┴────────────────────┘
                              │
                        ┌─────▼──────┐
                        │ PostgreSQL │
                        └────────────┘
```

## Services

- **frontend**: Interface utilisateur, orchestre les calls
- **cart**: Gestion panier, orchestration Saga
- **payment**: Traitement paiements (simule 20% failures)
- **notification**: Envoi confirmations

## Stack observabilité

- Prometheus (metrics)
- Loki (logs)
- Tempo (traces)
- Grafana (dashboards)

## Déploiement par module

### Module 1: Authorization & Policy (Kyverno)
```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-base-deployments.yaml
kubectl apply -f kyverno/policies/
```

### Module 2: Resilience & Observability
```bash
kubectl apply -f k8s/02-observability-stack.yaml
kubectl apply -f k8s/03-instrumented-apps.yaml
```

### Module 3: Advanced Ops
```bash
kubectl apply -f k8s/04-hpa.yaml
kubectl apply -f k8s/05-pdb.yaml
# Chaos tests in chaos/
```

## Quick Start

```bash
# Build images
./scripts/build-all.sh

# Deploy base stack
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-base-deployments.yaml

# Port-forward frontend
kubectl port-forward -n ecommerce svc/frontend 8080:8080

# Test
curl http://localhost:8080/checkout
```

## Structure

```
.
├── apps/               # Code source des services
│   ├── frontend/
│   ├── cart/
│   ├── payment/
│   └── notification/
├── k8s/                # Manifests Kubernetes
├── kyverno/            # Policies
├── chaos/              # Chaos experiments
├── scripts/            # Build & helpers
└── grafana/            # Dashboards
```
