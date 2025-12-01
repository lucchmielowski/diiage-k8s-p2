# DIIAGE P2 2025

Ce cours aborde les concepts avancés de Kubernetes, permettant d'approfondir votre compréhension de l'orchestration de
conteneurs et d'explorer des fonctionnalités plus complexes de la plateforme. Vous découvrirez les mécanismes internes,
les patterns d'architecture et les meilleures pratiques pour la gestion d'applications cloud-natives à grande échelle.

## Prérequis : Patterns Controllers et Operators dans Kubernetes

### Controllers

Les controllers sont des composants fondamentaux de Kubernetes qui implémentent des boucles de contrôle. Ils observent
l'état du cluster et travaillent constamment pour faire correspondre l'état actuel à l'état désiré. Par exemple :

- Le ReplicaSet Controller s'assure que le bon nombre de pods est en cours d'exécution
- Le Node Controller surveille l'état des nœuds et réagit lorsqu'un nœud tombe en panne

### Operators

Les operators étendent les capacités de Kubernetes en automatisant des tâches complexes spécifiques à une application.
Ils utilisent les Custom Resources Definitions (CRD) et suivent le pattern controller pour :

- Automatiser les installations et mises à jour
- Gérer les sauvegardes et restaurations
- Gérer des configurations complexes

### Avantages par rapport aux autres solutions

- Automatisation native et déclarative
- Extension facile des fonctionnalités via les CRDs
- Gestion cohérente des applications complexes
- Résilience grâce aux boucles de contrôle continues


## Index

### /monitoring

Ce dossier contient les configurations pour la surveillance et l'observabilité avec OpenTelemetry :

- Déploiement complet d'une stack de monitoring (Grafana, Prometheus, Tempo, OpenTelemetry Collector)
- Auto-instrumentation des applications via l'OpenTelemetry Operator
- Collecte et visualisation des trois piliers de l'observabilité : métriques, logs, et traces
- Applications de démonstration instrumentées (Python, Node.js, Java)
- Générateur de trafic pour produire des données de télémétrie

### /security

Ce dossier contient des exemples pratiques de sécurité Kubernetes :

- **RBAC** : ServiceAccounts, Roles, et RoleBindings avec le principe du moindre privilège
- **Network Policies** : Isolation réseau avec default-deny et règles d'autorisation granulaires
- **Kyverno** : Policy engine pour validation, mutation, et génération automatique de ressources
- Applications de démonstration (frontend, backend, database) illustrant les concepts de sécurité
- Exemples de policies de compliance (CIS Benchmark, Pod Security Standards)

### /gitops

Ce dossier contient une infrastructure GitOps complète basée sur ArgoCD :

- Installation et configuration d'ArgoCD via Helm
- Patterns GitOps : Git comme source de vérité unique
- Multi-environnements (dev, prod) avec ApplicationSets
- Déploiement d'applications via Helm charts
- Synchronisation automatique et détection de drift
- Gestion des accès aux repositories (public/privé, HTTPS/SSH)

### /resiliency

Ce dossier contient les principes et patterns de résilience système :

- **Golden Signals** : Les 4 métriques essentielles (Latency, Traffic, Errors, Saturation)
- **SLIs, SLOs, et SLAs** : Définition et mesure des objectifs de niveau de service
- **Error Budgets** : Gestion du compromis entre innovation et stabilité
- **Chaos Engineering** : Tests de résilience avec injection de pannes
- **Circuit Breakers et Rate Limiting** : Protection contre les cascades de pannes
- **Deployment Strategies** : Blue/Green, Canary, Rolling updates
- Patterns pratiques pour la résilience des applications cloud-native
