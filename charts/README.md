# Application Charts

Ce dossier contient les **définitions d'applications** sous forme de Helm charts, séparées des déclarations d'infrastructure GitOps.

## Separation of Concerns

Ce dossier fait partie d'une architecture qui sépare clairement :

- **Infrastructure (dossier `gitops/`)** : Déclare QUELLES applications déployer, OÙ et COMMENT (ApplicationSets, bootstrap, environnements)
- **Applications (ce dossier `charts/`)** : Définit CE QUI doit être déployé (structure et configuration des applications)

## Structure d'un chart

Chaque application suit la structure Helm standard :

```
charts/demo-app/
├── Chart.yaml                    # Métadonnées du chart (nom, version, description)
├── values.yaml                   # Valeurs par défaut
├── templates/                    # Templates Kubernetes
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml (optionnel)
└── environments/                 # Valeurs spécifiques par environnement
    ├── values-dev.yaml
    └── values-prod.yaml
```

## Applications disponibles

### demo-frontend

Application frontend web basée sur **nginx** servant un site statique simple.

**Valeurs par défaut** (`values.yaml`) :
- Image : `nginx:alpine`
- Port : 80
- Service type : ClusterIP
- Ingress activé avec host configurable

**Environnements** :
- **dev** : 1 replica, 50m CPU, 64Mi RAM, auto-sync activé
- **prod** : 3 replicas, 100m CPU, 128Mi RAM, sync manuel

### demo-backend

API backend REST basée sur **hashicorp/http-echo**.

**Valeurs par défaut** (`values.yaml`) :
- Image : `hashicorp/http-echo`
- Port : 5678
- Service type : ClusterIP

**Environnements** :
- **dev** : 1 replica, 50m CPU, 32Mi RAM, auto-sync activé
- **prod** : 3 replicas avec HPA, 200m CPU, 128Mi RAM, sync manuel

## Modifier une application

### Changer la configuration pour un environnement

1. Éditer le fichier values de l'environnement concerné :
```bash
# Pour dev
vim charts/demo-frontend/environments/values-dev.yaml

# Pour prod
vim charts/demo-frontend/environments/values-prod.yaml
```

2. Commit et push :
```bash
git add charts/demo-frontend/environments/values-dev.yaml
git commit -m "Update demo-frontend dev configuration"
git push
```

3. ArgoCD détecte le changement :
   - **dev** : sync automatique (appliqué immédiatement)
   - **prod** : sync manuel (nécessite une action dans l'UI ArgoCD)

### Modifier les templates Kubernetes

Éditer les fichiers dans `templates/` :
```bash
vim charts/demo-app/templates/deployment.yaml
```

Les modifications s'appliquent à tous les environnements utilisant ce chart.

### Changer les valeurs par défaut

Éditer `values.yaml` pour modifier les valeurs communes à tous les environnements :
```bash
vim charts/demo-app/values.yaml
```

## Ajouter une nouvelle application

### 1. Créer la structure du chart

```bash
mkdir -p charts/mon-app/{templates,environments}
```

### 2. Créer Chart.yaml

```yaml
apiVersion: v2
name: mon-app
description: Description de mon application
type: application
version: 0.1.0
appVersion: "1.0"
```

### 3. Créer values.yaml

```yaml
replicaCount: 1
image:
  repository: mon-image
  tag: latest
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

### 4. Créer les templates Kubernetes

Minimum requis : `deployment.yaml` et `service.yaml`

### 5. Créer les fichiers par environnement

```bash
# charts/mon-app/environments/values-dev.yaml
replicaCount: 1
resources:
  limits:
    cpu: 50m
    memory: 64Mi

# charts/mon-app/environments/values-prod.yaml
replicaCount: 3
resources:
  limits:
    cpu: 200m
    memory: 256Mi
```

### 6. Déclarer l'application dans l'infrastructure

Ajouter l'application dans `gitops/applicationsets/demo-apps.yaml` :
```yaml
- app: mon-app
  path: charts/mon-app
  env: dev
  namespace: dev
  valuesFile: environments/values-dev.yaml
  autoSync: "true"
```

### 7. Commit et push

```bash
git add charts/mon-app gitops/applicationsets/demo-apps.yaml
git commit -m "Add mon-app application"
git push
```

ArgoCD détectera automatiquement la nouvelle application et la déploiera.

## Best Practices

### Versioning
- Incrémenter `version` dans `Chart.yaml` à chaque modification significative
- Utiliser `appVersion` pour tracker la version de l'application déployée

### Configuration
- Mettre le minimum de valeurs dans `values.yaml` (défauts raisonnables)
- Surcharger dans `environments/values-*.yaml` selon les besoins
- Éviter de dupliquer les valeurs identiques entre environnements

### Templates
- Utiliser les helpers Helm pour éviter la duplication
- Paramétrer au maximum via values
- Ajouter des labels standards : `app`, `version`, `component`

### Resources
- Toujours définir `requests` et `limits`
- Commencer conservateur et ajuster selon les métriques
- Dev : ressources réduites, Prod : ressources adaptées à la charge

### Sécurité
- Ne jamais committer de secrets en clair
- Utiliser Sealed Secrets ou External Secrets Operator
- Définir des SecurityContext appropriés
- Scanner les images pour les vulnérabilités

## Migration vers un Helm Registry externe

Cette structure permet une migration facile vers un Helm registry externe (Harbor, ChartMuseum, OCI registry) :

1. **Package le chart** :
```bash
helm package charts/demo-app
```

2. **Publier dans un registry** :
```bash
helm push demo-app-0.1.0.tgz oci://registry.example.com/charts
```

3. **Mettre à jour l'ApplicationSet** :
```yaml
source:
  repoURL: oci://registry.example.com/charts
  chart: demo-app
  targetRevision: 0.1.0
```

## Liens utiles

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [ArgoCD Helm Support](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
