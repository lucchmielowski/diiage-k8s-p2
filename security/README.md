# Sécurité Kubernetes et Compliance avec Kyverno

## Introduction

La sécurité dans Kubernetes n'est pas une option mais une nécessité. Ce document couvre les concepts de base de la sécurité K8s et comment Kyverno permet d'automatiser la compliance et l'audit.

## 1. Pourquoi la sécurité K8s est critique ?

### Les risques principaux

- **Escalade de privilèges** : Un pod compromis peut accéder à l'API Kubernetes
- **Lateral movement** : Sans isolation réseau, un attaquant peut se déplacer entre pods
- **Supply chain attacks** : Images malveillantes ou non vérifiées
- **Secrets exposure** : Credentials exposés via variables d'environnement ou logs
- **Compliance violations** : Non-respect des standards de sécurité (CIS, NSA/CISA)

### Principe de défense en profondeur

Kubernetes offre plusieurs couches de sécurité :
1. Authentication & Authorization (RBAC)
2. Admission Control (Policies)
3. Network Security (Network Policies)
4. Runtime Security (Pod Security)

## 2. RBAC (Role-Based Access Control)

### Pourquoi ?

RBAC permet de contrôler **qui** peut faire **quoi** dans le cluster. Par défaut, tout est interdit.

### Concepts clés

- **ServiceAccount** : Identité pour les pods
- **Role/ClusterRole** : Ensemble de permissions
- **RoleBinding/ClusterRoleBinding** : Lie un utilisateur/SA à un rôle

### Exemple : Principe du moindre privilège
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**Bonne pratique** : Toujours créer des ServiceAccounts dédiés, jamais utiliser `default`.

## 3. Network Policies

### Pourquoi ?

Par défaut, tous les pods peuvent communiquer entre eux. C'est un risque majeur pour le lateral movement.

### Comment ça marche ?

Les Network Policies fonctionnent comme un firewall au niveau pod :
- **Ingress** : Qui peut se connecter à ce pod ?
- **Egress** : Vers où ce pod peut se connecter ?

### Exemple : Isolation par namespace
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: production
    ports:
    - protocol: TCP
      port: 443
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

Cette policy :
- Bloque tout le trafic entrant par défaut
- Autorise uniquement les connexions HTTPS vers le même namespace
- Autorise DNS (nécessaire pour le fonctionnement)

## 4. Pod Security Standards

### Les 3 niveaux

1. **Privileged** : Aucune restriction (à éviter en production)
2. **Baseline** : Bloque les élévations de privilèges connues
3. **Restricted** : Fortement restreint, bonnes pratiques de sécurité

### Configurations dangereuses à éviter
```yaml
# ❌ DANGEREUX
spec:
  containers:
  - name: app
    securityContext:
      privileged: true          # Accès complet au host
      runAsUser: 0              # Root
      allowPrivilegeEscalation: true
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /                   # Monte tout le filesystem du node
```
```yaml
# ✅ SÉCURISÉ
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

## 5. Kyverno : Policy-as-Code

### Pourquoi Kyverno ?

- **Déclaratif** : Les policies sont des ressources Kubernetes natives
- **Pas besoin d'apprendre un nouveau langage** : YAML comme tout le reste
- **3 modes** : Validate, Mutate, Generate
- **Reporting** : PolicyReports pour l'audit et la compliance

### Architecture
```
API Request → Admission Controller → Kyverno → Apply Policies → Accept/Reject/Modify
```

### Les 3 types de policies

1. **Validate** : Accepter ou rejeter une ressource
2. **Mutate** : Modifier automatiquement une ressource
3. **Generate** : Créer automatiquement des ressources

## 6. Exemple : ClusterPolicy de validation

### Use case : Bloquer les images non-registry approuvé
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-registry
  annotations:
    policies.kyverno.io/title: Require Approved Registry
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: high
    policies.kyverno.io/description: >-
      Les images doivent provenir uniquement de registries approuvés
      pour éviter les supply chain attacks.
spec:
  validationFailureAction: Enforce  # Enforce = bloquer, Audit = logger seulement
  background: true                   # Vérifier aussi les ressources existantes
  rules:
  - name: check-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: >-
        L'image doit provenir d'un registry approuvé (ghcr.io, gcr.io, ou votre-registry.com).
        Image actuelle: {{ request.object.spec.containers[0].image }}
      pattern:
        spec:
          containers:
          - image: "ghcr.io/* | gcr.io/* | votre-registry.com/*"
```

### Décortiquons cette policy

**metadata.annotations** : Documentation pour les équipes
- `title` : Nom lisible
- `category` : Classification (Best Practices, Security, etc.)
- `severity` : Impact (low, medium, high, critical)
- `description` : Pourquoi cette policy existe

**spec.validationFailureAction** :
- `Enforce` : Bloque la création/modification
- `Audit` : Permet mais log la violation (utile pour tester)

**spec.background** :
- `true` : Scan les ressources existantes (génère des PolicyReports)
- `false` : Uniquement les nouvelles ressources

**rules[].match** : Quelles ressources sont concernées
- Ici : tous les Pods

**rules[].validate.pattern** : Le pattern à respecter
- `|` signifie OU logique
- `*` est un wildcard

### Test de la policy
```bash
# Créer la policy
kubectl apply -f require-registry.yaml

# Test 1 : Image non-autorisée (devrait être bloquée)
kubectl run test --image=docker.io/nginx:latest

# Résultat attendu :
# Error from server: admission webhook "validate.kyverno.svc" denied the request
# L'image doit provenir d'un registry approuvé...

# Test 2 : Image autorisée (devrait fonctionner)
kubectl run test --image=ghcr.io/nginx:latest
```

## 7. Exemple : ClusterPolicy de mutation

### Use case : Ajouter automatiquement des security contexts
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-security-context
spec:
  validationFailureAction: Audit
  background: false
  rules:
  - name: add-runAsNonRoot
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
          containers:
          - (name): "*"
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                - ALL
              readOnlyRootFilesystem: true
```

Cette policy ajoute automatiquement des security contexts sécurisés à tous les pods.

## 8. Policy Reports : Audit et Compliance

### Pourquoi ?

Les PolicyReports permettent de :
- Voir les violations de compliance
- Générer des rapports d'audit
- Monitorer l'état de sécurité du cluster

### Exemple de PolicyReport

Kyverno génère automatiquement des PolicyReports :
```bash
kubectl get policyreport -A

# Détail d'un report
kubectl describe policyreport -n production
```
```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: cpol-require-registry
  namespace: production
results:
- message: "Image actuelle: docker.io/nginx:latest"
  policy: require-registry
  result: fail
  scored: true
  source: kyverno
  timestamp:
    seconds: 1234567890
  resources:
  - apiVersion: v1
    kind: Pod
    name: nginx-pod
    namespace: production
summary:
  fail: 1
  pass: 5
  skip: 0
  warn: 0
```

### Intégration monitoring

Les PolicyReports peuvent être exportés vers :
- **Prometheus** : Métriques de compliance
- **Grafana** : Dashboards de sécurité
- **Policy Reporter** : UI dédiée pour Kyverno

## 9. Cas pratiques avancés

### 9.1 Générer automatiquement des NetworkPolicies
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-default-deny-all
spec:
  rules:
  - name: default-deny
    match:
      any:
      - resources:
          kinds:
          - Namespace
    exclude:
      any:
      - resources:
          namespaces:
          - kube-system
          - kyverno
    generate:
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      name: default-deny-all
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      data:
        spec:
          podSelector: {}
          policyTypes:
          - Ingress
          - Egress
```

Chaque nouveau namespace aura automatiquement une NetworkPolicy deny-all.

### 9.2 Forcer la signature d'images
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "ghcr.io/votre-org/*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
              -----END PUBLIC KEY-----
```

### 9.3 Compliance CIS Benchmark
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: cis-5-2-1-minimize-admission-privileged
  annotations:
    policies.kyverno.io/title: CIS 5.2.1 - Minimize Privileged Containers
    policies.kyverno.io/category: CIS Benchmark
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: check-privileged
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "CIS 5.2.1: Privileged containers are not allowed"
      pattern:
        spec:
          containers:
          - =(securityContext):
              =(privileged): false
```

## 10. Bonnes pratiques

### Stratégie de déploiement des policies

1. **Phase 1 - Audit** : Déployer en mode `Audit` pour mesurer l'impact
2. **Phase 2 - Exceptions** : Créer des `PolicyException` pour les cas légitimes
3. **Phase 3 - Enforce** : Passer en mode `Enforce` progressivement

### Organisation des policies
```
policies/
├── 01-security/
│   ├── require-non-root.yaml
│   ├── drop-capabilities.yaml
│   └── readonly-filesystem.yaml
├── 02-compliance/
│   ├── cis-benchmark.yaml
│   └── nsa-cisa.yaml
├── 03-best-practices/
│   ├── require-labels.yaml
│   └── require-resources.yaml
└── 04-custom/
    └── company-specific.yaml
```

### Exceptions (PolicyException)
```yaml
apiVersion: kyverno.io/v1alpha1
kind: PolicyException
metadata:
  name: allow-privileged-monitoring
  namespace: monitoring
spec:
  exceptions:
  - policyName: cis-5-2-1-minimize-admission-privileged
    ruleNames:
    - check-privileged
  match:
    any:
    - resources:
        kinds:
        - Pod
        namespaces:
        - monitoring
        names:
        - "prometheus-*"
```

## 11. Monitoring et Alerting

### Métriques Kyverno importantes
```promql
# Nombre de policies en erreur
kyverno_policy_results_total{policy_validation_mode="enforce",policy_result="fail"}

# Taux de violation par policy
rate(kyverno_policy_results_total{policy_result="fail"}[5m])

# Latence des admissions
histogram_quantile(0.95, kyverno_admission_review_duration_seconds_bucket)
```

### Dashboard Grafana

Importer le dashboard officiel Kyverno : https://grafana.com/grafana/dashboards/13995

## 12. Ressources et documentation

### Kyverno
- Policies catalogue : https://kyverno.io/policies/
- Documentation : https://kyverno.io/docs/
- GitHub : https://github.com/kyverno/kyverno

### Standards de sécurité
- CIS Kubernetes Benchmark : https://www.cisecurity.org/benchmark/kubernetes
- NSA/CISA Hardening Guide : https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF
- Pod Security Standards : https://kubernetes.io/docs/concepts/security/pod-security-standards/

### Outils complémentaires
- Falco : Runtime security
- Trivy : Vulnerability scanning
- OPA/Gatekeeper : Alternative à Kyverno
- Policy Reporter : UI pour PolicyReports

## Exercices pratiques

### Exercice 1 : Créer une policy de validation
Créer une ClusterPolicy qui force tous les Deployments à avoir :
- Des resource requests/limits
- Au moins 2 replicas
- Des labels `app`, `version`, et `team`

### Exercice 2 : Mutation automatique
Créer une policy qui ajoute automatiquement une annotation `managed-by: kyverno` à tous les Deployments.

### Exercice 3 : Generate
Créer une policy qui génère automatiquement un LimitRange dans chaque nouveau namespace.

### Exercice 4 : Compliance report
- Déployer plusieurs policies en mode Audit
- Analyser les PolicyReports générés
- Identifier les pods non-compliant
- Proposer un plan de remediation

## Conclusion

La sécurité Kubernetes repose sur plusieurs piliers :
- **RBAC** pour le contrôle d'accès
- **Network Policies** pour l'isolation réseau
- **Pod Security** pour les configurations sécurisées
- **Kyverno** pour automatiser la compliance et l'audit

Kyverno permet de transformer ces bonnes pratiques en policies automatisées, garantissant un cluster sécurisé et conforme aux standards.

**Prochain step** : Déployer vos premières policies en mode Audit et analyser les résultats !
