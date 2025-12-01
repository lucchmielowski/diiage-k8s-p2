# GitOps Repository

Ce repo contient une infrastructure GitOps complète basée sur ArgoCD avec des applications d'exemple.

## Separation of Concerns

Ce repository suit le principe de **separation of concerns** entre :

**Infrastructure (ce dossier `gitops/`)** :
- Déclarations d'infrastructure GitOps
- ApplicationSets ArgoCD
- Configuration de bootstrap
- Définition des environnements (namespaces)
- **Configuration spécifique par environnement** (gitops/environments/values/)
- **Responsabilité** : Déclarer QUELLES applications déployer, OÙ et COMMENT, avec QUELS paramètres par environnement

**Application Charts (dossier `charts/` à la racine)** :
- Définitions des applications Helm **env-agnostic**
- Templates Kubernetes (Deployments, Services, Ingress, etc.)
- Valeurs par défaut uniquement
- **Responsabilité** : Définir CE QUI doit être déployé (structure de l'application), sans configuration d'environnement

**Avantages de cette séparation** :
- **Clarté** : Les équipes infra et dev travaillent sur des dossiers distincts
- **Réutilisabilité** : Les charts peuvent être versionnés et partagés indépendamment
- **Sécurité** : Permissions Git différentes pour infra vs app definitions
- **Évolutivité** : Les charts peuvent être déplacés vers un registry Helm externe facilement

## Quick Start

```bash
# 1. Installer ArgoCD via Helm
./gitops/argocd/install.sh

# 2. Créer les namespaces
kubectl apply -f gitops/environments/dev/namespace.yaml
kubectl apply -f gitops/environments/prod/namespace.yaml

# 3. Si repo privé, configurer l'accès Git (voir section "Accès Git Repository")
# Pour un repo public, passer directement à l'étape suivante

# 4. Bootstrap
kubectl apply -f gitops/bootstrap/argocd-bootstrap.yaml

# 5. Vérifier les applications
kubectl get applications -n argocd
```

## C'est quoi ?

GitOps = Git comme source de vérité unique pour l'infra et les apps.

**Principe** :
- Tout est déclaré en code (YAML, Helm, Kustomize, etc.)
- Git = état désiré
- Un agent (ArgoCD) sync automatiquement le cluster avec Git

## Pourquoi GitOps ?

### Avantages

**Traçabilité**
- Chaque changement = commit Git
- Historique complet avec qui/quand/pourquoi
- Rollback facile avec `git revert`

**Review & Validation**
- Pull requests pour tout changement
- Review de code pour l'infra
- CI pour valider les manifests avant merge

**Disaster Recovery**
- Cluster détruit ? `git clone` + ArgoCD = cluster restauré
- Pas de configuration manuelle perdue

**Sécurité**
- Pas besoin de `kubectl apply` en prod
- Pas de credentials kubectl distribués
- ArgoCD pull depuis Git (pas de push vers le cluster)

**Single Source of Truth**
- Plus de "ça marche chez moi"
- Pas de drift entre envs
- Documentation = code

## Comment ça marche avec ArgoCD ?

**Flow GitOps complet** :

1. Dev modifie un manifest → commit → push
2. PR review → merge
3. ArgoCD détecte le changement
4. ArgoCD applique sur le cluster
5. ArgoCD surveille et corrige le drift

## Accès Git Repository

### Repository public

Si votre repository est **public** (comme actuellement configuré avec `https://github.com/lucchmielowski/diiage-k8s-p2.git`), ArgoCD peut y accéder directement sans configuration supplémentaire.

### Repository privé

Si votre repository est **privé**, vous devez configurer l'authentification dans ArgoCD :

**Option 1 : HTTPS avec token**

```bash
# Créer un Personal Access Token sur GitHub
# Settings → Developer settings → Personal access tokens → Generate new token
# Permissions requises : repo (Full control of private repositories)

# Ajouter le repository dans ArgoCD
kubectl -n argocd create secret generic private-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/lucchmielowski/diiage-k8s-p2.git \
  --from-literal=password=YOUR_GITHUB_TOKEN \
  --from-literal=username=lucchmielowski

kubectl -n argocd label secret private-repo argocd.argoproj.io/secret-type=repository
```

**Option 2 : SSH avec clé privée**

```bash
# Générer une clé SSH (si vous n'en avez pas)
ssh-keygen -t ed25519 -C "argocd@cluster" -f ~/.ssh/argocd_ed25519

# Ajouter la clé publique dans GitHub
# Settings → SSH and GPG keys → New SSH key
cat ~/.ssh/argocd_ed25519.pub

# Ajouter le repository dans ArgoCD avec la clé privée
kubectl -n argocd create secret generic private-repo-ssh \
  --from-literal=type=git \
  --from-literal=url=git@github.com:lucchmielowski/diiage-k8s-p2.git \
  --from-file=sshPrivateKey=~/.ssh/argocd_ed25519

kubectl -n argocd label secret private-repo-ssh argocd.argoproj.io/secret-type=repository
```

**Option 3 : Via l'UI ArgoCD**

```bash
# 1. Accéder à l'UI ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 2. Se connecter (récupérer le password)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 3. Dans l'UI : Settings → Repositories → Connect Repo
# Remplir : URL, credentials (HTTPS ou SSH)
```

**Vérifier la connexion**

```bash
# Lister les repositories configurés
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository

# Vérifier dans l'UI ArgoCD
# Settings → Repositories → voir le statut "Successful"
```

## Applications incluses

### demo-frontend
Application web frontend utilisant **nginx** comme serveur web.
- **Dev** : 1 replica, 50m CPU, 32Mi RAM
- **Prod** : 3 replicas + autoscaling, 200m CPU, 128Mi RAM, TLS activé

### demo-backend
API backend utilisant **hashicorp/http-echo** pour simuler un service REST.
- **Dev** : 1 replica, 50m CPU, 32Mi RAM
- **Prod** : 3 replicas + autoscaling, 200m CPU, 128Mi RAM

Les deux apps sont déployées automatiquement en **dev** et manuellement en **prod** via ArgoCD.

## Structure repo

### Infrastructure GitOps (ce dossier)
```
gitops/
├── argocd/
│   └── install.sh                   # Script d'installation ArgoCD via Helm
├── applicationsets/
│   └── demo-apps.yaml               # ApplicationSet pour déployer toutes les apps
├── bootstrap/
│   └── argocd-bootstrap.yaml        # Bootstrap pour gérer les ApplicationSets
└── environments/
    ├── dev/
    │   └── namespace.yaml           # Namespace + quotas + limits dev
    ├── prod/
    │   └── namespace.yaml           # Namespace + quotas + limits prod
    └── values/                      # Configuration par environnement
        ├── demo-frontend-dev.yaml   # Config frontend dev
        ├── demo-frontend-prod.yaml  # Config frontend prod
        ├── demo-backend-dev.yaml    # Config backend dev
        └── demo-backend-prod.yaml   # Config backend prod
```

### Application Charts (à la racine du projet)
```
charts/
├── demo-frontend/                   # Application frontend (env-agnostic)
│   ├── Chart.yaml
│   ├── values.yaml                  # Valeurs par défaut uniquement
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ingress.yaml
└── demo-backend/                    # Application backend API (env-agnostic)
    ├── Chart.yaml
    ├── values.yaml                  # Valeurs par défaut uniquement
    └── templates/
        ├── deployment.yaml
        └── service.yaml
```

## Workflow typique

### Démarrage initial

**1. Installer ArgoCD dans le cluster via Helm**
```bash
./gitops/argocd/install.sh
```

Le script installe automatiquement ArgoCD et attend qu'il soit prêt.

**2. Créer les namespaces dev/prod**
```bash
kubectl apply -f gitops/environments/dev/namespace.yaml
kubectl apply -f gitops/environments/prod/namespace.yaml
```

**3. Bootstrap ArgoCD avec l'ApplicationSet**

Modifier `gitops/bootstrap/argocd-bootstrap.yaml` et `gitops/applicationsets/demo-apps.yaml` pour pointer vers votre repo Git, puis :

```bash
kubectl apply -f gitops/bootstrap/argocd-bootstrap.yaml
```

L'ApplicationSet va automatiquement créer 4 Applications ArgoCD :
- `demo-frontend-dev` (sync auto)
- `demo-frontend-prod` (sync manuel)
- `demo-backend-dev` (sync auto)
- `demo-backend-prod` (sync manuel)

### Modifier une application

**Exemple : changer le nombre de replicas du frontend en dev**

1. Éditer `gitops/environments/values/demo-frontend-dev.yaml`
```yaml
replicaCount: 3  # au lieu de 1
```

2. Commit et push
```bash
git add gitops/environments/values/demo-frontend-dev.yaml
git commit -m "Scale demo-frontend dev to 3 replicas"
git push
```

3. ArgoCD détecte le changement et applique automatiquement (dev est en auto-sync)

4. Pour prod (sync manuel), éditer `gitops/environments/values/demo-frontend-prod.yaml`, puis dans l'UI ArgoCD cliquer "Sync"

### Ajouter une nouvelle application

1. Créer le chart Helm env-agnostic dans `charts/mon-app/` (avec uniquement values.yaml par défaut)
2. Créer les fichiers de configuration par environnement dans `gitops/environments/values/` :
   - `gitops/environments/values/mon-app-dev.yaml`
   - `gitops/environments/values/mon-app-prod.yaml`
3. Ajouter l'app dans `gitops/applicationsets/demo-apps.yaml`
```yaml
- app: mon-app
  path: charts/mon-app
  env: dev
  namespace: dev
  valuesFile: gitops/environments/values/mon-app-dev.yaml
  autoSync: "true"
```
4. Commit et push
5. L'ApplicationSet crée automatiquement l'Application ArgoCD

## Best Practices

- Un repo par environnement OU branches par env
- Séparer app config et infra config
- Utiliser Kustomize/Helm pour éviter duplication
- Automated sync pour dev, manual pour prod (au début)
- Health checks et sync waves pour l'ordre de déploiement

## Pièges à éviter

- Pas de secrets en clair dans Git → utiliser sealed-secrets, SOPS, ou external-secrets
- Attention au drift : ArgoCD peut auto-heal ou juste notifier
- Self-managed ArgoCD = chicken & egg (bootstrapping)
