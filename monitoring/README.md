# Surveillance Kubernetes avec OpenTelemetry

Ce répertoire contient une stack de surveillance complète pour enseigner l'observabilité Kubernetes avec OpenTelemetry, incluant l'injection automatique de sidecars, le traçage distribué et la collecte de métriques.

## 📚 Table des matières

- [Connaissances prérequises](#connaissances-prérequises)
- [Vue d'ensemble de l'architecture](#vue-densemble-de-larchitecture)
- [Composants](#composants)
- [Prérequis](#prérequis)
- [Guide d'installation](#guide-dinstallation)
- [Utilisation de la stack](#utilisation-de-la-stack)
- [Exercices pour étudiants](#exercices-pour-étudiants)
- [Dépannage](#dépannage)

## 📖 Connaissances prérequises

L'observabilité moderne repose sur trois piliers complémentaires qui travaillent ensemble pour fournir une vue complète de la santé et du comportement de votre système. Chaque pilier sert un objectif spécifique et répond à différentes questions sur votre système.

### Métriques

Les métriques sont des mesures quantitatives du comportement du système collectées au fil du temps. Elles fournissent des points de données numériques qui peuvent être agrégés, analysés et visualisés pour comprendre les tendances et les modèles. Les exemples incluent l'utilisation du CPU, la consommation de mémoire, les taux de requêtes, les compteurs d'erreurs et les temps de réponse.

**Ce qu'elles vous disent :** Les métriques répondent aux questions "quoi" et "quand" concernant la santé de votre système. Elles vous montrent que quelque chose se produit (par exemple, utilisation élevée du CPU, taux d'erreur accru) et quand cela se produit.

**Cas d'usage :**
- Surveillance de la santé du système et des tendances de performance
- Configuration d'alertes basées sur des seuils
- Planification de la capacité et optimisation des ressources
- Création de tableaux de bord pour la surveillance en temps réel

**Outils dans cette stack :** Prometheus collecte et stocke les métriques, Grafana les visualise.

### Logs

Les logs sont des enregistrements discrets d'événements qui se sont produits dans votre système à des moments précis. Chaque entrée de log inclut généralement un horodatage, un niveau de sévérité et des informations contextuelles détaillées sur ce qui s'est passé. Les logs capturent l'histoire de l'exécution de votre application.

**Ce qu'ils vous disent :** Les logs répondent à la question "que s'est-il passé". Ils fournissent un contexte détaillé sur des événements spécifiques, des erreurs et des changements d'état dans votre application.

**Cas d'usage :**
- Débogage des erreurs et exceptions d'application
- Audit des actions utilisateur et des changements système
- Compréhension de la séquence d'événements menant à un problème
- Conformité et surveillance de la sécurité

**Outils dans cette stack :** OpenTelemetry Collector peut recevoir des logs ; en production, vous ajouteriez typiquement Loki ou Elasticsearch pour l'agrégation et la recherche de logs.

### Traces

Les traces suivent le parcours complet d'une requête lorsqu'elle traverse votre système distribué. Une trace consiste en plusieurs spans, où chaque span représente une unité de travail (comme un appel de fonction ou une communication service-à-service). Les traces montrent les relations entre différents composants et combien de temps chaque étape a pris.

**Ce qu'elles vous disent :** Les traces répondent aux questions "où" et "pourquoi" concernant les problèmes de performance. Elles révèlent quel service ou composant cause des ralentissements et montrent le chemin complet qu'une requête prend à travers votre architecture de microservices.

**Cas d'usage :**
- Identification des goulots d'étranglement de performance dans les systèmes distribués
- Compréhension des dépendances de services et des modèles de communication
- Débogage de problèmes qui s'étendent sur plusieurs services
- Optimisation des flux de requêtes et réduction de la latence

**Outils dans cette stack :** Tempo stocke et interroge les traces, Grafana les visualise avec des graphes de services et des chronologies de traces.

### Pourquoi utiliser les trois ensemble ?

Utiliser les métriques, les logs et les traces ensemble crée une stratégie d'observabilité puissante :

1. **Les métriques** vous alertent qu'il y a un problème (par exemple, taux d'erreur élevé)
2. **Les logs** fournissent le contexte sur ce qui s'est mal passé (par exemple, messages d'erreur spécifiques)
3. **Les traces** vous aident à identifier précisément où dans votre système distribué le problème a pris naissance (par exemple, quel service est lent)

Cette approche holistique est essentielle pour comprendre et déboguer les architectures de microservices complexes dans Kubernetes, où une seule requête utilisateur peut toucher des dizaines de services.

## 🏗️ Vue d'ensemble de l'architecture

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

## 🧩 Composants

### 1. **OpenTelemetry Operator**
- Gère les déploiements d'OpenTelemetry Collector
- Injecte automatiquement des sidecars d'instrumentation dans les pods
- Prend en charge l'auto-instrumentation Python, Java, Node.js, .NET

### 2. **OpenTelemetry Collector**
- Reçoit les données de télémétrie via OTLP (gRPC et HTTP)
- Traite et met en lot les données
- Exporte les traces vers Tempo et les métriques vers Prometheus

### 3. **Tempo**
- Backend de traçage distribué
- Stocke et interroge les traces
- Intégré avec Grafana pour la visualisation

### 4. **Prometheus**
- Base de données de métriques de séries temporelles
- Scrape les métriques depuis les applications et Kubernetes
- Reçoit les métriques depuis OpenTelemetry Collector
- **Note :** Cette stack utilise Prometheus standalone. Le Prometheus Operator (voir [Alternative dans l'Exercice 7](#exercice-7--configurer-des-alertes-avancé)) est une alternative plus avancée qui simplifie la gestion des alertes et la découverte de services via des CRDs.

### 5. **Grafana**
- Plateforme de visualisation unifiée
- Pré-configurée avec les sources de données Prometheus et Tempo
- Inclut des tableaux de bord d'exemple

## ✅ Prérequis

- Cluster Kubernetes (v1.24+)
- `kubectl` configuré pour accéder à votre cluster
- `helm` (v3.0+) installé
- Compréhension de base des concepts Kubernetes et Helm

## 📥 Guide d'installation

### Option 1 : Installation automatisée (Recommandée)

Le moyen le plus simple d'installer toute la stack de surveillance :

```bash
cd monitoring
chmod +x install.sh
./install.sh
```

Ce script va :
1. Ajouter les dépôts Helm requis
2. Installer cert-manager (pour les webhooks OpenTelemetry Operator)
3. Installer OpenTelemetry Operator
4. Déployer tous les composants de surveillance via Helm (Tempo, Prometheus, Grafana, OpenTelemetry Collector)
5. Créer la ressource Instrumentation

**Après l'installation**, accédez à Grafana :

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Ouvrez http://localhost:3000 (admin/admin)

---

### Option 2 : Installation manuelle avec Helm

#### Étape 1 : Ajouter les dépôts Helm

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

#### Étape 2 : Installer cert-manager

cert-manager est requis pour les webhooks OpenTelemetry Operator.

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Attendre que cert-manager soit prêt
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager \
  deployment/cert-manager-webhook \
  deployment/cert-manager-cainjector \
  -n cert-manager
```

#### Étape 3 : Installer OpenTelemetry Operator

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.91.0/opentelemetry-operator.yaml

# Attendre que l'opérateur soit prêt
kubectl wait --for=condition=available --timeout=300s \
  deployment/opentelemetry-operator-controller-manager \
  -n opentelemetry-operator-system
```

#### Étape 4 : Créer le namespace monitoring

```bash
kubectl apply -f namespace.yaml
```

#### Étape 5 : Déployer la stack de surveillance via Helm

**Installer Tempo :**

```bash
helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  --values tempo/values.yaml \
  --wait
```

**Installer Prometheus :**

```bash
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --values prometheus/values.yaml \
  --wait
```

**Installer Grafana :**

```bash
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values grafana/values.yaml \
  --wait
```

**Installer OpenTelemetry Collector :**

```bash
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --values opentelemetry-collector/values.yaml \
  --wait
```

#### Étape 6 : Créer la ressource Instrumentation

Cette ressource définit comment les applications doivent être auto-instrumentées.

```bash
kubectl apply -f demo-instrumented/instrumentation.yaml
```

#### Étape 7 : Déployer les applications de démonstration (Optionnel)

Déployer des applications d'exemple avec auto-instrumentation :

```bash
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml
```

Cela déploie trois applications de démonstration :
- **demo-python-app** : Serveur HTTP Python avec auto-instrumentation
- **demo-nodejs-app** : Serveur HTTP Node.js avec auto-instrumentation
- **demo-java-app** : Application Spring Boot avec auto-instrumentation

#### Étape 8 : Accéder à la stack

**Port-forward Grafana :**

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Accédez à Grafana à : http://localhost:3000
- Nom d'utilisateur : `admin`
- Mot de passe : `admin`

**Port-forward Prometheus (optionnel) :**

```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

Accédez à Prometheus à : http://localhost:9090

---

### Personnalisation des déploiements Helm

Tous les fichiers de valeurs Helm sont situés dans leurs répertoires de composants respectifs :
- `grafana/values.yaml` - Configuration Grafana
- `prometheus/values.yaml` - Configuration Prometheus
- `tempo/values.yaml` - Configuration Tempo
- `opentelemetry-collector/values.yaml` - Configuration Collector

Vous pouvez personnaliser ces fichiers pour ajuster :
- Les limites et demandes de ressources
- La persistance du stockage
- Les politiques de rétention
- Les intervalles de scraping
- Les configurations de sources de données

## 🎯 Utilisation de la stack

### Comment activer l'auto-instrumentation

Pour activer l'auto-instrumentation pour vos applications, ajoutez des annotations à votre spécification Pod :

#### Application Python

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

#### Application Node.js

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-nodejs: "monitoring/demo-instrumentation"
```

#### Application Java

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-java: "monitoring/demo-instrumentation"
```

#### Application .NET

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-dotnet: "monitoring/demo-instrumentation"
```

### Activer le scraping Prometheus

Ajoutez ces annotations pour permettre à Prometheus de scraper les métriques depuis vos pods :

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

### Visualiser les traces dans Grafana

1. Ouvrez Grafana (http://localhost:3000)
2. Naviguez vers **Explore** (icône boussole)
3. Sélectionnez **Tempo** comme source de données
4. Utilisez l'onglet **Search** pour trouver les traces
5. Filtrez par nom de service, opération, tags, etc.

### Visualiser les métriques dans Grafana

1. Dans Grafana, naviguez vers **Explore**
2. Sélectionnez **Prometheus** comme source de données
3. Utilisez des requêtes PromQL, par exemple :
   - `rate(http_requests_total[5m])` - Taux de requêtes HTTP
   - `otelcol_receiver_accepted_spans` - Spans reçus par le collector
   - `up` - Disponibilité du service

## 🎓 Exercices pour étudiants

### Exercice 1 : Vérifier l'installation

**Objectif :** S'assurer que tous les composants fonctionnent correctement.

**Tâches :**
1. Lister tous les pods dans le namespace `monitoring`
2. Vérifier que tous les déploiements sont prêts
3. Vérifier que l'OpenTelemetry Collector reçoit des données

**Commandes :**
```bash
kubectl get pods -n monitoring
kubectl get deployments -n monitoring
kubectl logs -n monitoring deployment/otel-collector-collector -f
```

**Résultats attendus :**
- Tous les pods devraient être dans l'état `Running`
- Tous les déploiements devraient afficher `READY 1/1`
- Les logs du collector ne devraient montrer aucune erreur

---

### Exercice 2 : Déployer une application instrumentée

**Objectif :** Déployer votre première application auto-instrumentée.

**Tâches :**
1. Déployer l'application Python de démonstration
2. Vérifier que le sidecar a été injecté
3. Générer du trafic
4. Trouver les traces dans Grafana

**Commandes :**
```bash
# Déployer
kubectl apply -f demo-instrumented/demo-app-instrumented.yaml

# Vérifier si le sidecar a été injecté
kubectl get pod -n monitoring -l app=demo-python-app -o yaml | grep -A 5 "initContainers"

# Générer du trafic
kubectl port-forward -n monitoring svc/demo-python-app 8080:8080
# Dans un autre terminal :
for i in {1..20}; do curl http://localhost:8080; sleep 1; done

# Accéder à Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Ouvrir http://localhost:3000 et explorer les traces
```

**Questions :**
- Combien de conteneurs y a-t-il dans le pod après l'injection ?
- Quelles traces voyez-vous dans Tempo ?
- Quelles métriques apparaissent dans Prometheus ?

---

### Exercice 3 : Ajouter l'instrumentation aux applications existantes

**Objectif :** Ajouter l'auto-instrumentation à l'application demo-frontend existante.

**Tâches :**
1. Copier le chart Helm `demo-frontend`
2. Ajouter l'annotation d'instrumentation
3. Déployer et vérifier que les traces apparaissent

**Indice :** Ajoutez ceci aux métadonnées du template de déploiement :
```yaml
annotations:
  instrumentation.opentelemetry.io/inject-python: "monitoring/demo-instrumentation"
```

---

### Exercice 4 : Créer un tableau de bord personnalisé

**Objectif :** Construire un tableau de bord Grafana pour votre application.

**Tâches :**
1. Dans Grafana, créer un nouveau tableau de bord
2. Ajouter un panneau affichant le taux de requêtes
3. Ajouter un panneau affichant le taux d'erreurs
4. Ajouter un panneau affichant la durée des requêtes (p95, p99)

**Exemples de requêtes PromQL :**
```promql
# Taux de requêtes
rate(http_server_requests_total[5m])

# Taux d'erreurs
rate(http_server_requests_total{status=~"5.."}[5m])

# Durée des requêtes p95
histogram_quantile(0.95, rate(http_server_duration_bucket[5m]))
```

---

### Exercice 5 : Tracer une requête distribuée

**Objectif :** Comprendre le traçage distribué à travers les services.

**Tâches :**
1. Déployer à la fois `demo-frontend` et `demo-backend` avec instrumentation
2. Faire une requête qui va frontend → backend
3. Trouver la trace distribuée dans Tempo
4. Analyser les spans de la trace

**Questions :**
- Combien de spans y a-t-il dans la trace ?
- Quelle est la durée totale de la requête ?
- Où la plupart du temps est-il passé ?

---

### Exercice 6 : Investiguer un problème de performance

**Objectif :** Utiliser les outils d'observabilité pour déboguer un service lent.

**Scénario :** Un de vos services répond lentement.

**Tâches :**
1. Trouver les traces lentes dans Tempo (durée > 1s)
2. Identifier quel span prend le plus de temps
3. Corréler avec les métriques dans Prometheus
4. Proposer une solution

---

### Exercice 7 : Configurer des alertes (Avancé)

**Objectif :** Créer une alerte Prometheus pour des taux d'erreur élevés.

**Tâches :**
1. Créer un ConfigMap avec des règles d'alerte Prometheus
2. Configurer Prometheus pour charger ces règles
3. Définir une alerte pour un taux d'erreur > 5%
4. Tester l'alerte en générant des erreurs

**Note :** Cette stack utilise Prometheus standalone (pas le Prometheus Operator), donc les alertes sont configurées via des fichiers de règles plutôt que via la ressource `PrometheusRule` CRD.

**Étape 1 : Créer un ConfigMap avec les règles d'alerte**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
  namespace: monitoring
data:
  alerts.yml: |
    groups:
    - name: app
      rules:
      - alert: HighErrorRate
        expr: rate(http_server_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 5% for {{ $labels.service }}"
```

**Étape 2 : Mettre à jour la configuration Prometheus**

Éditer `prometheus/values.yaml` pour ajouter la configuration des règles d'alerte :

```yaml
serverFiles:
  prometheus.yml:
    scrape_configs:
      # ... (configuration existante)
    
    # Ajouter la configuration des règles d'alerte
    rule_files:
      - /etc/prometheus/rules/*.yml

# Ajouter un volume pour monter le ConfigMap
server:
  extraVolumes:
    - name: alert-rules
      configMap:
        name: prometheus-alerts
  extraVolumeMounts:
    - name: alert-rules
      mountPath: /etc/prometheus/rules
```

**Étape 3 : Appliquer les changements**

```bash
# Créer le ConfigMap
kubectl apply -f prometheus-alerts-configmap.yaml

# Mettre à jour Prometheus
helm upgrade prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --values prometheus/values.yaml
```

**Étape 4 : Vérifier les alertes**

Accéder à Prometheus et naviguer vers **Alerts** pour voir les alertes configurées.

---

#### Alternative : Utiliser Prometheus Operator (Plus simple)

Si vous préférez une approche plus simple et plus native à Kubernetes pour gérer les alertes, vous pouvez utiliser le **Prometheus Operator** au lieu de Prometheus standalone. Le Prometheus Operator fournit des Custom Resource Definitions (CRDs) qui simplifient la gestion de Prometheus et de ses règles d'alerte.

**Avantages du Prometheus Operator :**
- ✅ Gestion des alertes via des ressources Kubernetes (`PrometheusRule` CRD)
- ✅ Découverte automatique des services à scraper via `ServiceMonitor`
- ✅ Configuration déclarative via des ressources Kubernetes
- ✅ Intégration native avec AlertManager
- ✅ Gestion simplifiée des mises à jour et de la configuration

**Pour utiliser Prometheus Operator :**

1. **Remplacer le chart Prometheus** dans `install.sh` :
   ```bash
   # Au lieu de prometheus-community/prometheus
   helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --values prometheus-operator/values.yaml
   ```

2. **Créer des alertes avec PrometheusRule** (beaucoup plus simple) :
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
           description: "Error rate is above 5% for {{ $labels.service }}"
   ```

3. **Découvrir automatiquement les services** avec `ServiceMonitor` :
   ```yaml
   apiVersion: monitoring.coreos.com/v1
   kind: ServiceMonitor
   metadata:
     name: my-app
     namespace: monitoring
   spec:
     selector:
       matchLabels:
         app: my-app
     endpoints:
     - port: http
       path: /metrics
   ```

**Note :** Cette stack utilise actuellement Prometheus standalone pour rester simple et léger. Le Prometheus Operator est recommandé pour les environnements de production où vous avez besoin de plus de fonctionnalités et d'une gestion plus déclarative.

---

### Exercice 8 : Personnaliser l'instrumentation

**Objectif :** Modifier la ressource Instrumentation pour changer l'échantillonnage.

**Tâches :**
1. Éditer le `instrumentation.yaml`
2. Changer le sampler de `always_on` à `traceidratio`
3. Définir le taux d'échantillonnage à 50%
4. Appliquer et observer la différence

**Indice :**
```yaml
sampler:
  type: traceidratio
  argument: "0.5"
```

## 🐛 Dépannage

### Problèmes de release Helm

**Lister toutes les releases Helm :**
```bash
helm list -n monitoring
```

**Vérifier le statut d'une release Helm :**
```bash
helm status <release-name> -n monitoring
# Exemples : grafana, prometheus, tempo, otel-collector
```

**Obtenir les valeurs d'une release Helm :**
```bash
helm get values <release-name> -n monitoring
```

**Restaurer une mise à jour échouée :**
```bash
helm rollback <release-name> -n monitoring
```

**Désinstaller et réinstaller :**
```bash
helm uninstall <release-name> -n monitoring
helm upgrade --install <release-name> <chart> --namespace monitoring --values <values-file> --wait
```

### Pods ne démarrent pas

**Vérifier le statut du pod :**
```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

**Vérifier le statut du déploiement Helm :**
```bash
kubectl get deployments -n monitoring
helm status grafana -n monitoring
helm status prometheus -n monitoring
helm status tempo -n monitoring
helm status otel-collector -n monitoring
```

### Aucune trace n'apparaît

**Vérifier les logs du collector :**
```bash
# Note : Le nom du déploiement Helm peut différer
kubectl logs -n monitoring deployment/otel-collector-opentelemetry-collector -f
```

**Vérifier l'instrumentation :**
```bash
kubectl get instrumentation -n monitoring
kubectl describe pod <app-pod> -n monitoring
```

**Problèmes courants :**
- Le format de l'annotation est incorrect (doit être `namespace/instrumentation-name`)
- Le langage de l'application n'est pas pris en charge pour l'auto-instrumentation
- Problèmes de connectivité réseau vers le collector
- Les noms de services ont changé avec Helm (par exemple, `prometheus-server` au lieu de `prometheus`)

### Grafana n'affiche pas de données

**Vérifier la configuration de la source de données :**
1. Grafana → Configuration → Data Sources
2. Tester la connexion à Prometheus et Tempo
3. Vérifier que les URLs sont correctes (notez les noms de services Helm) :
   - Prometheus : `http://prometheus-server.monitoring.svc.cluster.local:80`
   - Tempo : `http://tempo.monitoring.svc.cluster.local:3200`

**Reconfigurer les sources de données via Helm :**
```bash
# Éditer la section datasources de grafana/values.yaml
# Puis mettre à jour la release
helm upgrade grafana grafana/grafana -n monitoring --values grafana/values.yaml
```

### Utilisation élevée des ressources

**Réduire la rétention dans Prometheus :**

Éditer `prometheus/values.yaml` :
```yaml
server:
  retention: "1d"  # Au lieu de 7d
```

Appliquer les changements :
```bash
helm upgrade prometheus prometheus-community/prometheus -n monitoring --values prometheus/values.yaml
```

**Réduire la rétention dans Tempo :**

Éditer `tempo/values.yaml` :
```yaml
tempo:
  config: |
    compactor:
      compaction:
        block_retention: 24h  # Au lieu de 48h
```

Appliquer les changements :
```bash
helm upgrade tempo grafana/tempo -n monitoring --values tempo/values.yaml
```

**Ajuster l'échantillonnage :**

Éditer `demo-instrumented/instrumentation.yaml` :
```yaml
sampler:
  type: traceidratio
  argument: "0.1"  # Échantillonner seulement 10% des traces
```

Appliquer les changements :
```bash
kubectl apply -f demo-instrumented/instrumentation.yaml
```

### Changements de configuration non appliqués

Si vous modifiez un fichier de valeurs et que les changements n'apparaissent pas :

```bash
# Mettre à jour la release Helm avec les nouvelles valeurs
helm upgrade <release-name> <chart> -n monitoring --values <values-file>

# Forcer la recréation des pods
helm upgrade <release-name> <chart> -n monitoring --values <values-file> --force

# Vérifier la nouvelle configuration
helm get values <release-name> -n monitoring
```

## 📖 Ressources supplémentaires

### Documentation OpenTelemetry
- [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Auto-instrumentation](https://opentelemetry.io/docs/instrumentation/)

### Outils d'observabilité
- [Prometheus](https://prometheus.io/docs/)
- [Grafana Tempo](https://grafana.com/docs/tempo/latest/)
- [Grafana](https://grafana.com/docs/grafana/latest/)

### Ressources PromQL
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

## 🚀 Prochaines étapes

- Intégrer avec Loki pour l'agrégation de logs
- Ajouter l'alerting avec AlertManager
- Explorer l'intégration avec un service mesh (Istio/Linkerd)
- Configurer le stockage à long terme (S3, GCS)
- Implémenter les SLOs et budgets d'erreur
