# Resiliency Principles Guide

## Table of Contents
- [Introduction](#introduction)
- [Golden Signals](#golden-signals)
- [SLIs, SLOs, and SLAs](#slis-slos-and-slas)
- [Error Budgets](#error-budgets)
- [Chaos Engineering](#chaos-engineering)
- [Circuit Breakers and Rate Limiting](#circuit-breakers-and-rate-limiting)
- [Retry Strategies](#retry-strategies)
- [Graceful Degradation](#graceful-degradation)
- [Observability](#observability)
- [Deployment Strategies](#deployment-strategies)
- [Practical Patterns](#practical-patterns)

## Introduction

La résilience système, c'est la capacité d'un système à continuer de fonctionner malgré les pannes, les pics de charge, ou les comportements inattendus. C'est pas juste éviter les pannes - c'est savoir comment réagir quand elles arrivent.

### Principe de base

```
Pannes inévitables → Design pour la panne → Système résilient
```

**Les 4 piliers:**
1. **Détection** - Savoir quand ça casse
2. **Isolation** - Empêcher la propagation
3. **Récupération** - Revenir à l'état normal
4. **Apprentissage** - Améliorer continuellement

## Golden Signals

Les **Golden Signals** sont les 4 métriques essentielles pour monitorer n'importe quel service.

### Architecture de monitoring

```
┌─────────────────────────────────────────────────────────┐
│                    Service à monitorer                   │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │ Latency  │  │ Traffic  │  │  Errors  │  │Saturation││
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬────┘ │
└───────┼─────────────┼─────────────┼──────────────┼──────┘
        │             │             │              │
        └─────────────┴─────────────┴──────────────┘
                          │
                    ┌─────▼──────┐
                    │ Prometheus │
                    └─────┬──────┘
                          │
                    ┌─────▼──────┐
                    │  Grafana   │
                    └────────────┘
```

### Les 4 Signaux

**1. LATENCY (Latence)**
```
Request → Processing → Response
   │          │           │
   └──────────┴───────────┘
          Time = Latency

Mesures importantes:
- p50 (médiane) : 50% des requêtes plus rapides
- p95 : 95% des requêtes plus rapides
- p99 : 99% des requêtes plus rapides
- p99.9 : Pour détecter les outliers
```

**Pourquoi les percentiles?**
```
Average = 100ms peut cacher:
├─ 90% des requêtes @ 50ms  ✓
└─ 10% des requêtes @ 550ms ✗

p95 = 200ms révèle mieux la réalité
```

**2. TRAFFIC (Trafic)**
```
Volume de demandes par unité de temps

┌─────────────────────────────────┐
│     Requêtes/sec au fil du      │
│             temps                │
│                                  │
│     ▲                           │
│ 500 │      ╱╲                   │
│     │     ╱  ╲    ╱╲            │
│ 250 │────╱────╲──╱──╲───────    │
│     │   ╱      ╲╱    ╲          │
│   0 └──────────────────────► t  │
└─────────────────────────────────┘
      Normal   Spike  Normal
```

**3. ERRORS (Erreurs)**
```
Types d'erreurs à tracker:

┌─────────────┐
│HTTP Status  │
├─────────────┤
│ 2xx → OK    │
│ 4xx → Client│ ← Valide mais à monitorer
│ 5xx → Server│ ← Erreur système critique
└─────────────┘

Autres erreurs:
- Timeouts
- Panics/Crashes
- Exceptions non gérées
- Validation failures
```

**Calcul du taux d'erreur:**
```
                  Requêtes en erreur
Error Rate = ──────────────────────────
                 Total requêtes

Exemple: 15 erreurs / 10000 requêtes = 0.15% error rate
```

**4. SATURATION (Saturation)**
```
Utilisation des ressources critiques

CPU:     [████████░░] 80%  ⚠️
Memory:  [██████░░░░] 60%  ✓
Disk I/O:[█████████░] 90%  ⚠️
Network: [███░░░░░░░] 30%  ✓

Seuils typiques:
- 70%  → Attention
- 85%  → Alerte
- 95%  → Critique
```

### Relation entre les signaux

```
                    ┌──────────┐
                    │ TRAFFIC  │
                    │    ↑     │
                    └──────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐     ┌─────────┐    ┌──────────┐
    │ LATENCY │────►│ ERRORS  │    │SATURATION│
    │ augmente│     │augmentent│    │ augmente │
    └─────────┘     └─────────┘    └──────────┘
                         │               │
                         └───────┬───────┘
                                 ▼
                          Cascading failure
```

### Dashboard type

```
┌────────────────────────────────────────────────────┐
│ Service: API Gateway                               │
├────────────────────────────────────────────────────┤
│ Latency (p95)          │ Traffic                   │
│ ▲                      │ ▲                         │
│ │  ╱╲                  │ │    ╱╲╱╲                │
│ │ ╱  ╲                 │ │   ╱    ╲               │
│ └───────► 245ms        │ └────────► 1.2k req/s    │
├────────────────────────┼───────────────────────────┤
│ Error Rate             │ Saturation                │
│ ▲                      │ CPU:   [███░] 35%         │
│ │ ╱╲                   │ Mem:   [█████] 52%        │
│ │╱  ╲                  │ I/O:   [██░░] 23%         │
│ └───────► 0.12%        │                           │
└────────────────────────┴───────────────────────────┘
```

## SLIs, SLOs, and SLAs

### Vue d'ensemble

```
┌─────────────────────────────────────────────┐
│              Hiérarchie                     │
├─────────────────────────────────────────────┤
│                                             │
│  SLI (Indicator)                            │
│    │                                        │
│    │  "Comment on mesure?"                  │
│    │  Ex: % requêtes < 200ms                │
│    │                                        │
│    ▼                                        │
│  SLO (Objective)                            │
│    │                                        │
│    │  "Quel est notre target?"              │
│    │  Ex: 99.9% sur 30 jours                │
│    │                                        │
│    ▼                                        │
│  SLA (Agreement)                            │
│    │                                        │
│    │  "Qu'est-ce qu'on garantit?"           │
│    │  Ex: 99.5% ou remboursement            │
│    │                                        │
└─────────────────────────────────────────────┘
```

### SLI (Service Level Indicator)

Métrique quantitative qui mesure un aspect du service.

```
Types de SLI:

┌──────────────────┐
│  Availability    │ → % de requêtes réussies
├──────────────────┤
│  Latency         │ → % de requêtes < threshold
├──────────────────┤
│  Throughput      │ → Requêtes/sec traitées
├──────────────────┤
│  Correctness     │ → % de résultats corrects
└──────────────────┘
```

**Exemple de calcul:**
```
Availability SLI sur 1 heure:

Total requêtes:     10,000
Requêtes réussies:   9,985
Requêtes échouées:      15

SLI = 9,985 / 10,000 = 0.9985 = 99.85%
```

### SLO (Service Level Objective)

Target interne pour un SLI. Structure: **SLI ≥ Target sur période**

```
┌───────────────────────────────────────────┐
│           Exemple de SLO                  │
├───────────────────────────────────────────┤
│                                           │
│  99.9% des requêtes                       │
│  doivent réussir                          │
│  sur une fenêtre glissante de 30 jours    │
│                                           │
├───────────────────────────────────────────┤
│  Composants:                              │
│  • Métrique: % requêtes réussies          │
│  • Target: 99.9%                          │
│  • Période: 30 jours                      │
└───────────────────────────────────────────┘
```

**Fenêtre de mesure:**
```
Calendar-based (mensuel):
├─────────────────────────────┤
Jan 1               Jan 31

Rolling window (30 jours glissants):
      ├─────────────────────────────┤
    Aujourd'hui          -30j
```

### SLA (Service Level Agreement)

Contrat légal avec conséquences si non respecté.

```
┌────────────────────────────────────────┐
│        Relation SLO vs SLA             │
├────────────────────────────────────────┤
│                                        │
│  Performance actuelle:  99.99% ✓       │
│         │                              │
│         │ (buffer)                     │
│         ▼                              │
│  SLO interne:          99.9%  ✓        │
│         │                              │
│         │ (marge de sécurité)          │
│         ▼                              │
│  SLA contractuel:      99.5%  ✓        │
│         │                              │
│         ▼                              │
│  Pénalités             <99.5% ✗        │
│                                        │
└────────────────────────────────────────┘

Principe: SLA < SLO < Performance
```

### Table de downtime autorisé

| SLO    | Downtime/an | Downtime/mois | Downtime/semaine |
|--------|-------------|---------------|------------------|
| 90%    | 36.5j       | 3j            | 16.8h            |
| 99%    | 3.65j       | 7.2h          | 1.68h            |
| 99.9%  | 8.76h       | 43.8m         | 10.1m            |
| 99.95% | 4.38h       | 21.9m         | 5.04m            |
| 99.99% | 52.6m       | 4.38m         | 1.01m            |

**Calcul:**
```
SLO 99.9% sur 30 jours:

30 jours = 43,200 minutes
Uptime requis = 43,200 × 0.999 = 43,156.8 min
Downtime autorisé = 43,200 - 43,156.8 = 43.2 min
```

### Multiple SLOs

Services complexes ont plusieurs SLOs:

```
┌──────────────────────────────────────────┐
│        API Service SLOs                  │
├──────────────────────────────────────────┤
│                                          │
│  Availability:  99.9%  (30d window)      │
│  Latency p95:   <200ms (99% du temps)    │
│  Latency p99:   <500ms (99.5% du temps)  │
│  Throughput:    >1000 req/s              │
│                                          │
└──────────────────────────────────────────┘

Chaque SLO a son propre error budget
```

## Error Budgets

L'**error budget** est le temps de panne acceptable selon ton SLO.

### Concept

```
┌──────────────────────────────────────────┐
│     Error Budget = 100% - SLO            │
├──────────────────────────────────────────┤
│                                          │
│  SLO 99.9% → Error Budget 0.1%           │
│                                          │
│  Sur 30 jours:                           │
│  • 43,200 minutes total                  │
│  • 43.2 minutes de downtime OK           │
│  • 43,156.8 minutes uptime requis        │
│                                          │
└──────────────────────────────────────────┘
```

### Fonctionnement

```
┌────────────────────────────────────────────────┐
│           Mois en cours                        │
├────────────────────────────────────────────────┤
│                                                │
│  Jour 1-10:  Budget utilisé: 10min / 43.2min   │
│              Reste: 33.2min  ✓ Vert            │
│                                                │
│  Jour 11-15: Incident 20min                    │
│              Budget utilisé: 30min / 43.2min   │
│              Reste: 13.2min  ⚠️  Jaune         │
│                                                │
│  Jour 16-20: Incident 15min                    │
│              Budget utilisé: 45min / 43.2min   │
│              Reste: -1.8min  ✗ Rouge           │
│              → FREEZE FEATURES                 │
│                                                │
└────────────────────────────────────────────────┘
```

### Policy de décision

```
┌─────────────────────────────────────────────┐
│      État Error Budget → Action             │
├─────────────────────────────────────────────┤
│                                             │
│  > 50% restant  → Ship rapide               │
│                   Prends des risques        │
│                   Innovation               │
│                                             │
│  20-50% restant → Prudence                  │
│                   Review changements        │
│                   Tests supplémentaires    │
│                                             │
│  < 20% restant  → Ralentir releases         │
│                   Focus sur fixes           │
│                   Postmortems              │
│                                             │
│  Épuisé (0%)    → FREEZE TOTAL              │
│                   Bugs critiques only       │
│                   Root cause analysis      │
│                                             │
└─────────────────────────────────────────────┘
```

### Burn Rate

Vitesse à laquelle on consomme le budget.

```
┌──────────────────────────────────────────┐
│        Burn Rate Calculation             │
├──────────────────────────────────────────┤
│                                          │
│         Taux d'erreur actuel             │
│  BR = ─────────────────────────          │
│         Taux d'erreur autorisé           │
│                                          │
├──────────────────────────────────────────┤
│  Exemples pour SLO 99.9%:                │
│                                          │
│  Taux actuel 0.1% → BR = 0.1/0.1 = 1x    │
│  (Normal, budget épuisé en 30j)          │
│                                          │
│  Taux actuel 0.5% → BR = 0.5/0.1 = 5x    │
│  (Rapide, budget épuisé en 6j)           │
│                                          │
│  Taux actuel 1.0% → BR = 1.0/0.1 = 10x   │
│  (Critique, budget épuisé en 3j)         │
│                                          │
└──────────────────────────────────────────┘
```

### Multi-Window Alerting

Stratégie pour détecter les problèmes rapidement sans faux positifs.

```
┌────────────────────────────────────────────────────┐
│         Multi-Window Multi-Burn-Rate               │
├────────────────────────────────────────────────────┤
│                                                    │
│  Fenêtre    Burn Rate    Consomme budget  Alerte  │
│                                                    │
│  1 heure      14.4x        2% en 1h       2min    │
│  (rapide)                  Budget en 3j            │
│                                                    │
│  6 heures      6x          2% en 6h       15min   │
│  (moyen)                   Budget en 5j            │
│                                                    │
│  3 jours       1x         10% en 3j       1h      │
│  (lent)                    Budget en 30j           │
│                                                    │
└────────────────────────────────────────────────────┘

Principe: 
- Fenêtre courte + burn rate élevé = Incident actif
- Fenêtre longue + burn rate faible = Dégradation lente
```

### Visualisation

```
Error Budget au fil du temps (30 jours)

 100% ┤
      │ ●●●
   75%│    ●●●●
      │        ●●
   50%│          ●●●●        Déploiement
      │              ●●      problématique
   25%│                ●         ↓
      │                 ●●●●●●●●●
    0%└─────────────────────────────────────→
      1   5   10  15  20  25  30 (jours)
      
      ✓ Jours 1-17: Budget sain
      ⚠️  Jour 18: Incident commence
      ✗ Jours 19-30: Budget épuisé, freeze
```

### Récupération du budget

```
Mode: Rolling Window (30 jours glissants)

Jour 1: Incident 20min
        Budget: 43.2 - 20 = 23.2min restant

Jour 31: La fenêtre glisse, Jour 1 sort
         Budget: Reset à 43.2min
         
C'est automatique avec rolling windows
```

## Chaos Engineering

Chaos engineering = injecter des pannes **volontairement** pour tester la résilience.

### Philosophie

```
┌────────────────────────────────────────────┐
│  "On casse pour apprendre avant que        │
│   la production ne casse toute seule"      │
└────────────────────────────────────────────┘

Hypothèse → Expérience → Observation → Apprentissage
```

### Les 5 Principes

```
1. Définir le Steady State
   ↓
   [Système normal: latence, errors, throughput]

2. Hypothèse de résilience
   ↓
   "Le système devrait survivre si le pod X crash"

3. Injecter des pannes réelles
   ↓
   [Kill pod, add latency, partition network]

4. Observer la déviation
   ↓
   Est-ce que le steady state est maintenu?

5. Automatiser et répéter
   ↓
   Game days, CI/CD chaos tests
```

### Blast Radius

Contrôler l'impact des expériences.

```
┌─────────────────────────────────────────────────┐
│            Progression du Chaos                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  1. Dev/Staging                                 │
│     └─ 100% des ressources                      │
│        Risk: Bas                                │
│                                                 │
│  2. Production - Canary                         │
│     └─ 1% du traffic                            │
│        Risk: Contrôlé                           │
│                                                 │
│  3. Production - Région isolée                  │
│     └─ 1 région sur 3                           │
│        Risk: Modéré                             │
│                                                 │
│  4. Production - Full                           │
│     └─ Toutes les régions                       │
│        Risk: Élevé (game days only)             │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Types d'Expériences

**1. Infrastructure**
```
┌────────────────────────────────┐
│   Pod/Container Level          │
├────────────────────────────────┤
│ • Pod termination              │
│ • Container kill               │
│ • Resource stress (CPU/Memory) │
└────────────────────────────────┘

┌────────────────────────────────┐
│   Network Level                │
├────────────────────────────────┤
│ • Latency injection            │
│ • Packet loss                  │
│ • Network partition            │
│ • DNS failures                 │
│ • Bandwidth limitation         │
└────────────────────────────────┘

┌────────────────────────────────┐
│   Node Level                   │
├────────────────────────────────┤
│ • Node drain                   │
│ • Node shutdown                │
│ • Disk pressure                │
│ • Clock skew                   │
└────────────────────────────────┘
```

**2. Application**
```
┌────────────────────────────────┐
│   Service Degradation          │
├────────────────────────────────┤
│ • Slow responses               │
│ • Error injection (5xx)        │
│ • Timeout simulation           │
│ • Resource exhaustion          │
└────────────────────────────────┘

┌────────────────────────────────┐
│   Data Layer                   │
├────────────────────────────────┤
│ • Database unavailability      │
│ • Slow queries                 │
│ • Connection pool exhaustion   │
│ • Corrupt data injection       │
└────────────────────────────────┘
```

### Exemple: Network Chaos

```
État Normal:
┌─────────┐  10ms   ┌─────────┐
│Service A│◄───────►│Service B│
└─────────┘         └─────────┘
     ✓ OK

Injection Latency (100ms):
┌─────────┐  110ms  ┌─────────┐
│Service A│◄═══════►│Service B│
└─────────┘         └─────────┘
     ? Test de timeout

Partition Network:
┌─────────┐    ✗    ┌─────────┐
│Service A│  ╱╱╱╱╱  │Service B│
└─────────┘         └─────────┘
     ? Test de fallback
```

### Anatomy d'une Expérience Chaos

```
┌──────────────────────────────────────────────┐
│  1. BASELINE                                 │
│     Capturer métriques normales              │
│     (latency, errors, throughput)            │
└──────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────┐
│  2. HYPOTHÈSE                                │
│     "Si on tue un pod, les autres prennent   │
│      le relais sans impact utilisateur"      │
└──────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────┐
│  3. INJECTION                                │
│     kubectl delete pod service-x-abc123      │
│     + Observer pendant 5 minutes             │
└──────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────┐
│  4. VALIDATION                               │
│     ✓ Latency p99 < 200ms maintenu          │
│     ✓ Error rate < 0.1% maintenu            │
│     ✓ Nouveau pod démarré en < 30s          │
└──────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────┐
│  5. CONCLUSION                               │
│     Hypothèse validée ✓                      │
│     OU                                       │
│     Problème détecté → Action Items          │
└──────────────────────────────────────────────┘
```

### Game Days

Sessions d'entraînement pour incidents majeurs.

```
┌─────────────────────────────────────────────┐
│           Anatomy d'un Game Day             │
├─────────────────────────────────────────────┤
│                                             │
│  Pre-Game (1 semaine avant)                 │
│  ├─ Définir scénarios                       │
│  ├─ Préparer observabilité                  │
│  ├─ Brief équipe                            │
│  └─ Review runbooks                         │
│                                             │
│  Game Day (2-3 heures)                      │
│  ├─ 10:00 - Baseline capture                │
│  ├─ 10:15 - Incident injection              │
│  │          (ex: zone AWS down)             │
│  ├─ 10:16 - Équipe détecte                  │
│  ├─ 10:20 - Debug & mitigation              │
│  ├─ 10:45 - Résolution                      │
│  └─ 11:00 - Service restauré                │
│                                             │
│  Post-Game (immédiat)                       │
│  ├─ Debrief à chaud (30min)                 │
│  ├─ Ce qui a marché                         │
│  ├─ Ce qui a échoué                         │
│  └─ Action items                            │
│                                             │
│  Post-Mortem (3 jours après)                │
│  ├─ Document complet                        │
│  ├─ Timeline détaillée                      │
│  ├─ Root cause                              │
│  └─ Preventive measures                     │
│                                             │
└─────────────────────────────────────────────┘
```

### Outils Chaos

```
┌─────────────────────────────────────────┐
│         Chaos Mesh (CNCF)               │
│  ├─ Pod Chaos                           │
│  ├─ Network Chaos                       │
│  ├─ IO Chaos                            │
│  ├─ Stress Chaos                        │
│  ├─ Time Chaos                          │
│  └─ Kernel Chaos                        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Litmus (CNCF)                   │
│  ├─ Pre-built experiments               │
│  ├─ Chaos workflows                     │
│  └─ Chaos metrics                       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Toxiproxy                       │
│  ├─ Network proxy                       │
│  ├─ Latency injection                   │
│  ├─ Bandwidth limitation                │
│  └─ Connection failures                 │
└─────────────────────────────────────────┘
```

### Scheduling Chaos

```
Fréquence recommandée:

Dev/Staging:
└─ Continuous (chaque deploy)

Production - Automated:
├─ Pod kills: Quotidien
├─ Network chaos: Hebdomadaire
└─ Node drain: Hebdomadaire

Production - Game Days:
└─ Major scenarios: Mensuel ou trimestriel
```

## Circuit Breakers and Rate Limiting

Patterns pour prévenir les cascades de pannes et protéger les ressources.

### Circuit Breaker

Coupe temporairement les appels à un service défaillant pour éviter la surcharge.

**États du Circuit Breaker:**

```
┌──────────────────────────────────────────────────┐
│                Circuit States                    │
└──────────────────────────────────────────────────┘

    État CLOSED (Normal)
    ┌─────────────────┐
    │   Requests OK   │
    │   ✓✓✓✓✓✓✓✓     │
    └────────┬────────┘
             │
             │ Trop d'erreurs (ex: 50% sur 10 req)
             ▼
    ┌─────────────────┐
    │   État OPEN     │
    │   Fail Fast     │
    │   ✗✗✗✗✗✗✗✗     │ ← Rejette immédiatement
    └────────┬────────┘
             │
             │ Après timeout (ex: 60s)
             ▼
    ┌─────────────────┐
    │ État HALF-OPEN  │
    │ Teste avec      │
    │ N requêtes      │
    └────────┬────────┘
             │
        ┌────┴────┐
        │         │
    Succès    Échec
        │         │
        ▼         ▼
    CLOSED     OPEN
```

**Timeline d'un incident:**

```
Time →

00:00  [CLOSED] ✓✓✓✓✓✓  Tout OK
       │
00:05  [CLOSED] ✓✓✗✗✗✗  Service commence à fail
       │
00:06  [OPEN]   Circuit s'ouvre
       │        Requêtes rejetées immédiatement
       │        Pas de charge sur service défaillant
       │
01:06  [HALF-OPEN] Test avec 3 requêtes
       │
       ├─ Si ✓✓✓ → [CLOSED] Reprise normale
       │
       └─ Si ✗✗✗ → [OPEN] Reste fermé 60s de plus
```

**Configuration typique:**

```
┌────────────────────────────────────┐
│  Circuit Breaker Settings          │
├────────────────────────────────────┤
│                                    │
│  Failure Threshold: 50%            │
│  (% échecs pour ouvrir)            │
│                                    │
│  Request Threshold: 10             │
│  (minimum de requêtes à analyser)  │
│                                    │
│  Timeout: 60s                      │
│  (durée avant HALF-OPEN)           │
│                                    │
│  Half-Open Requests: 3             │
│  (requêtes test)                   │
│                                    │
└────────────────────────────────────┘
```

### Cascade Failure Prevention

Pourquoi le circuit breaker est critique:

```
Sans Circuit Breaker:
┌──────┐    ┌──────┐    ┌──────┐
│ API  │───►│ DB   │    │Users │
│      │◄───│(slow)│    │      │
└──────┘    └──────┘    └──────┘
   │                        │
   │ Accumule requêtes      │
   │ Threads bloqués        │
   │ Memory overflow        │
   ▼                        ▼
  CRASH  ────────────►  All fails

Avec Circuit Breaker:
┌──────┐    ┌──────┐    ┌──────┐
│ API  │ ✗  │ DB   │    │Users │
│      │    │(slow)│    │      │
└──────┘    └──────┘    └──────┘
   │                        │
   │ Circuit OPEN           │
   │ Fail fast              │
   │ Ressources libérées    │
   ▼                        ▼
  OK     ────────────►  Partial service
                        (cache, fallback)
```

### Rate Limiting

Limite le nombre de requêtes acceptées sur une période.

**Algorithmes:**

**1. Token Bucket**
```
Bucket capacity: 100 tokens
Refill rate: 10 tokens/sec

    Bucket [████████░░] 80 tokens
              ↑
              │ +10/sec
              │
    Request consomme 1 token
              ↓
    Accept si token disponible
    Reject si bucket vide

Avantage: Permet des bursts
```

**2. Leaky Bucket**
```
    Requests arrivent
         ↓↓↓
    ┌──────────┐
    │ ░░░░░░░░ │ Buffer
    │ ░░░░░░░░ │
    │ ░░░░░░░░ │
    └────┬─────┘
         │ Constant rate
         ↓
    Processed

Avantage: Lisse le trafic
```

**3. Fixed Window**
```
Window: 1 minute
Limit: 100 requests

10:00:00 - 10:00:59  [███████░░░] 75 req  ✓
10:01:00 - 10:01:59  [██████████] 100 req ✓
10:02:00 - 10:02:59  [████░░░░░░] 40 req  ✓

Problème: Burst à la frontière
10:00:30 - 50 req ✓
10:01:00 - 100 req ✓
→ 150 req en 30 secondes!
```

**4. Sliding Window**
```
Current time: 10:05:30
Window: 1 minute glissant

10:04:30 ────────────► 10:05:30
     [Compte requêtes dans cette fenêtre]

Plus précis, pas de burst aux frontières
```

### Rate Limiting Strategies

**Per-User Limiting:**
```
┌────────────────────────────────┐
│  User A: 100 req/min           │
│  User B: 100 req/min           │
│  User C: 1000 req/min (premium)│
└────────────────────────────────┘

Empêche qu'un user monopolise le service
```

**Global Limiting:**
```
┌────────────────────────────────┐
│  Total API: 10,000 req/sec     │
│                                │
│  Protège l'infra globale       │
└────────────────────────────────┘
```

**Tiered Limiting:**
```
Request Path:

1. WAF/CDN: 100k req/s
           ↓
2. Load Balancer: 50k req/s
           ↓
3. API Gateway: 10k req/s
           ↓
4. Service: 1k req/s
           ↓
5. Database: 500 queries/s

Chaque layer protège le suivant
```

### Response Headers

```
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1640000000
Retry-After: 60

Body:
{
  "error": "rate_limit_exceeded",
  "message": "Try again in 60 seconds"
}
```

### Kubernetes Rate Limiting

**Envoy/Istio Level:**
```
┌──────────────────────────────┐
│    Envoy Sidecar             │
│                              │
│  Local rate limit:           │
│  - 1000 tokens/sec           │
│  - Burst: 2000               │
│                              │
│  Global rate limit:          │
│  - Redis backend             │
│  - Distributed counter       │
│                              │
└──────────────────────────────┘
```

**Ingress Level:**
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"
```

## Retry Strategies

Réessayer intelligemment les opérations qui échouent.

### Exponential Backoff

Délai qui augmente exponentiellement entre chaque retry.

```
Attempt 1: Immediate
           ↓ Fail
           Wait 1s
           
Attempt 2: After 1s
           ↓ Fail
           Wait 2s
           
Attempt 3: After 2s
           ↓ Fail
           Wait 4s
           
Attempt 4: After 4s
           ↓ Fail
           Wait 8s
           
Attempt 5: After 8s
           ↓ Fail
           Give up

Formule: delay = base × 2^(attempt - 1)
```

**Avec Jitter:**

```
Sans jitter (problème):
Time →
10:00:00 → 1000 clients retry en même temps
           │││││││││
           ▼▼▼▼▼▼▼▼▼
           Thundering herd!
           Server overwhelmed

Avec jitter (solution):
10:00:00 → Clients retry avec délais variés
           │ │  │ │  │ │  │ │
           ▼ ▼  ▼ ▼  ▼ ▼  ▼ ▼
           Spread load
           Server OK

Jitter = delay ± random(0, delay/2)
```

**Visualisation:**

```
Delay (secondes)

64 │                              ●
   │                            /
32 │                        ●
   │                      /
16 │                  ●
   │                /
 8 │            ●
   │          /
 4 │      ●
   │    /
 2 │  ●
   │/
 1 ●
   └─────────────────────────────────►
   1  2  3  4  5  6  7  8  9  10 (attempts)
   
   Avec cap maximum à 60s
```

### Decision Tree pour Retries

```
┌─────────────────────────┐
│   Opération échoue      │
└───────────┬─────────────┘
            │
            ▼
    ┌───────────────┐
    │ Erreur type?  │
    └───────┬───────┘
            │
    ┌───────┴────────┐
    │                │
    ▼                ▼
┌─────────┐    ┌──────────┐
│Transient│    │Permanent │
│(temp)   │    │(persist) │
└────┬────┘    └────┬─────┘
     │              │
     │              ▼
     │         ┌─────────┐
     │         │ STOP    │
     │         │No Retry │
     │         └─────────┘
     │
     ▼
┌──────────────────┐
│ Idempotent?      │
└────┬─────────────┘
     │
  ┌──┴───┐
  │      │
  ▼      ▼
 Oui    Non
  │      │
  │      └──→ STOP (risque de duplicate)
  │
  ▼
┌──────────────────┐
│ Retry avec       │
│ exponential      │
│ backoff + jitter │
└──────────────────┘
```

### Erreurs: Transient vs Permanent

```
┌─────────────────────────────────────┐
│     Erreurs Transient (Retry)       │
├─────────────────────────────────────┤
│ • Network timeout                   │
│ • Connection refused                │
│ • 503 Service Unavailable           │
│ • 429 Too Many Requests             │
│ • 500 Internal Server Error         │
│ • Deadlock (DB)                     │
│ • Temporary unavailability          │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│     Erreurs Permanent (No Retry)    │
├─────────────────────────────────────┤
│ • 400 Bad Request                   │
│ • 401 Unauthorized                  │
│ • 403 Forbidden                     │
│ • 404 Not Found                     │
│ • 422 Unprocessable Entity          │
│ • Validation errors                 │
│ • Data corruption                   │
└─────────────────────────────────────┘
```

### Idempotence

**Critique:** Les opérations retryées DOIVENT être idempotentes.

```
Non-Idempotent (DANGER):
┌──────────────────────────┐
│ IncrementCounter()       │
│   counter = counter + 1  │
└──────────────────────────┘

Appel 1: counter = 5 → 6  ✓
Retry:   counter = 6 → 7  ✗ (erreur!)

Idempotent (SAFE):
┌──────────────────────────┐
│ SetCounter(value)        │
│   counter = value        │
└──────────────────────────┘

Appel 1: counter = 6      ✓
Retry:   counter = 6      ✓ (même résultat)
```

**Idempotency Key Pattern:**

```
Request avec clé unique:
POST /payments
{
  "idempotency_key": "pay_abc123",
  "amount": 100
}

Serveur:
┌────────────────────────────────┐
│ 1. Check si key existe         │
│    └─ Oui → Return cached result│
│    └─ Non → Process payment    │
│                                │
│ 2. Process payment             │
│                                │
│ 3. Store result avec key       │
│                                │
│ 4. Return result               │
└────────────────────────────────┘

Retry avec même key:
→ Returns cached result
→ No double payment ✓
```

### Timeouts

**Toujours** définir des timeouts stricts.

```
┌──────────────────────────────────────┐
│      Timeout Hierarchy               │
├──────────────────────────────────────┤
│                                      │
│  Request Timeout: 30s                │
│    │                                 │
│    ├─ Connection Timeout: 5s         │
│    ├─ TLS Handshake: 5s              │
│    ├─ Response Header: 10s           │
│    └─ Read Timeout: 20s              │
│                                      │
└──────────────────────────────────────┘

Principe: Chaque phase a son timeout
```

**Timeout Cascade:**

```
Client → LB → API → DB
 30s     25s   20s   10s

Chaque hop réduit le timeout
pour laisser du temps aux layers précédents
```

### Retry Budget

Limiter les retries pour éviter l'amplification.

```
┌──────────────────────────────────────┐
│         Retry Budget                 │
├──────────────────────────────────────┤
│                                      │
│  Requêtes originales:  1000/sec      │
│  Retry budget:         20% = 200/sec │
│                                      │
│  Si toutes les requêtes fail:        │
│  → Max 200 retries/sec               │
│  → Pas 1000 retries                  │
│                                      │
│  Évite d'aggraver la situation       │
│                                      │
└──────────────────────────────────────┘
```

### Best Practices

```
✓ DO:
├─ Use exponential backoff
├─ Add jitter (±50%)
├─ Set max retry count (3-5)
├─ Set max delay cap (60s)
├─ Use context.Context pour cancellation
├─ Log retry attempts
├─ Monitor retry rate
├─ Only retry idempotent operations
└─ Use idempotency keys

✗ DON'T:
├─ Retry indefinitely
├─ Retry without backoff (hammering)
├─ Retry non-idempotent ops
├─ Retry permanent errors
├─ Ignore retry budget
└─ Retry without timeout
```

## Graceful Degradation

Dégrader les fonctionnalités progressivement plutôt que de tout casser.

### Principe

```
Système Brittle (fragile):
Feature A → Dependency fails → Everything fails ✗

Système Resilient:
Feature A → Dependency fails → Fallback to basic version ✓
```

### Degradation Ladder

```
┌────────────────────────────────────────┐
│      Performance Degradation           │
├────────────────────────────────────────┤
│                                        │
│  100% │ ████████████ Full features    │
│       │ • ML recommendations           │
│       │ • Real-time data               │
│       │ • Personalization              │
│       │                                │
│   75% │ █████████░░░ Reduced features  │
│       │ • Static recommendations       │
│       │ • Cached data (5min)           │
│       │ • Basic personalization        │
│       │                                │
│   50% │ ██████░░░░░░ Core features     │
│       │ • Popular items only           │
│       │ • Cached data (1h)             │
│       │ • No personalization           │
│       │                                │
│   25% │ ███░░░░░░░░░ Minimal           │
│       │ • Static content               │
│       │ • Stale cache OK               │
│       │                                │
│    0% │ ░░░░░░░░░░░░ Failure           │
│       │ • Service down                 │
│                                        │
└────────────────────────────────────────┘
```

### Stratégies

**1. Feature Flags**

```
┌──────────────────────────────────────┐
│    Feature Flag Decision Tree        │
└──────────────────────────────────────┘

GetRecommendations(userID)
    │
    ▼
┌──────────────────┐
│ ML Service UP?   │
└────┬─────────┬───┘
     │         │
    YES       NO
     │         │
     ▼         ▼
  ML Reco   Popular
  (best)    (fallback)
     │         │
     └────┬────┘
          ▼
      Return data
```

**2. Tiered Fallbacks**

```
Level 1: Real-time ML
         ↓ (fails)
Level 2: Cached ML (1h old)
         ↓ (fails)
Level 3: Rule-based recommendations
         ↓ (fails)
Level 4: Popular items
         ↓ (fails)
Level 5: Static defaults

Chaque niveau est "moins bon" mais disponible
```

**3. Cache with Stale Data**

```
┌────────────────────────────────────┐
│      Cache Freshness Strategy      │
├────────────────────────────────────┤
│                                    │
│  Fresh (< 5min):   Serve directly  │
│  Stale (< 1h):     Serve + Refresh │
│  Very stale (< 1d): Serve if DB down│
│  Expired (> 1d):   Reject          │
│                                    │
└────────────────────────────────────┘

Timeline:
0────5min────1h────────1d────► time
│    │       │          │
Fresh│  Stale │  Very    │ Expired
     │  (OK)  │  stale   │
     │        │  (if     │
     │        │  needed) │
```

**Flow avec stale data:**

```
Request → Check cache
          │
          ├─ Fresh? → Return ✓
          │
          ├─ Stale? → Return stale ⚠️
          │           + Async refresh
          │
          └─ Expired? → Try DB
                        │
                        ├─ DB OK → Return fresh ✓
                        │
                        └─ DB down → Return stale anyway ⚠️
                                     (better than nothing)
```

**4. Partial Responses**

```
Dashboard Request:
┌─────────────────────────────────┐
│  Component 1: User Info         │ ✓ Success (50ms)
│  Component 2: Stats             │ ✓ Success (120ms)
│  Component 3: Recommendations   │ ✗ Failed (timeout)
│  Component 4: Notifications     │ ✓ Success (80ms)
└─────────────────────────────────┘

Response:
{
  "user_info": { ... },        // ✓
  "stats": { ... },            // ✓
  "recommendations": null,     // ✗ (mais pas de blocage)
  "notifications": [ ... ],    // ✓
  "errors": [
    "recommendations temporarily unavailable"
  ]
}

3/4 composants fonctionnent = Partial success
```

**Architecture:**

```
┌────────────────────────────────────────┐
│         Parallel Fetching              │
└────────────────────────────────────────┘

Request
   │
   ├─────┬─────┬─────┬─────┐
   │     │     │     │     │
   ▼     ▼     ▼     ▼     ▼
  API1  API2  API3  API4  API5
 (5s)  (10s) (20s) (3s)  (15s)
   │     │     │     │     │
   └─────┴─────┴─────┴─────┘
            │
         Timeout: 12s
            │
    ┌───────┴────────┐
    │                │
 Success          Timeout
 (API1,4,2)       (API3,5)
    │                │
    └───────┬────────┘
            ▼
    Partial response
    + Error details
```

### Load Shedding

Rejeter volontairement des requêtes pour protéger le système.

```
┌────────────────────────────────────────┐
│        Load Shedding Thresholds        │
├────────────────────────────────────────┤
│                                        │
│  Load < 70%:  Accept all              │
│               │                        │
│  Load 70-85%: Start shedding          │
│               │ • Drop low-priority    │
│               │ • Serve from cache     │
│               │                        │
│  Load 85-95%: Aggressive shedding     │
│               │ • Only critical users  │
│               │ • Basic features only  │
│               │                        │
│  Load > 95%:  Emergency mode          │
│               └─ Maintenance page      │
│                                        │
└────────────────────────────────────────┘
```

**Priority-based shedding:**

```
Request Classification:
┌─────────────────────────┐
│  P0: Critical           │ → Always serve
│      (payments, auth)   │
├─────────────────────────┤
│  P1: Important          │ → Serve if < 85% load
│      (core features)    │
├─────────────────────────┤
│  P2: Nice-to-have       │ → Serve if < 70% load
│      (analytics)        │
├─────────────────────────┤
│  P3: Optional           │ → Serve if < 50% load
│      (recommendations)  │
└─────────────────────────┘
```

### Bulkhead Pattern

Isoler les ressources pour éviter qu'une panne ne contamine tout.

```
Without Bulkheads (bad):
┌──────────────────────────┐
│   Shared Thread Pool     │
│   ████████████████       │
│   All 100 threads used   │
│   by slow DB queries     │
│   → No threads for API   │
│   → Everything blocked   │
└──────────────────────────┘

With Bulkheads (good):
┌──────────────────────────┐
│  DB Pool      │ API Pool │
│  ████████     │ ████     │
│  50 threads   │ 30 thds  │
│  (saturated)  │ (OK)     │
│               │          │
│  ✗ DB slow    │ ✓ API OK │
└──────────────────────────┘
```

**Kubernetes example:**

```
┌────────────────────────────────────┐
│      Pod Resource Isolation        │
├────────────────────────────────────┤
│                                    │
│  Critical Service:                 │
│  ├─ requests: 2 CPU, 4Gi          │
│  ├─ limits: 4 CPU, 8Gi            │
│  └─ guaranteed QoS                 │
│                                    │
│  Background Jobs:                  │
│  ├─ requests: 0.5 CPU, 1Gi        │
│  ├─ limits: 1 CPU, 2Gi            │
│  └─ burstable QoS                  │
│                                    │
│  → Jobs can't starve critical      │
│                                    │
└────────────────────────────────────┘
```

## Observability

Les **3 piliers** de l'observabilité.

### Vue d'ensemble

```
┌────────────────────────────────────────────┐
│         Observability Triangle             │
└────────────────────────────────────────────┘

              METRICS
                 ▲
                ╱ ╲
               ╱   ╲
              ╱     ╲
             ╱       ╲
            ╱ System  ╲
           ╱  Health   ╲
          ╱             ╲
         ╱               ╲
        ╱                 ╲
    LOGS ◄─────────────► TRACES

Chaque pilier répond à une question:
- Metrics: "Qu'est-ce qui ne va pas?"
- Logs: "Pourquoi ça ne va pas?"
- Traces: "Où est le problème?"
```

### 1. Metrics

Données numériques agrégées dans le temps.

**Types de métriques:**

```
┌─────────────────────────────────┐
│  Counter                        │
│  ────────────────────────       │
│  Toujours en augmentation       │
│  Ex: requests_total             │
│                                 │
│      ▲                          │
│  500 │        ╱                 │
│  250 │      ╱                   │
│    0 └────╱──────────► time     │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  Gauge                          │
│  ────────────────────────       │
│  Peut monter ou descendre       │
│  Ex: cpu_usage, memory          │
│                                 │
│      ▲    ╱╲                    │
│  100 │   ╱  ╲  ╱╲               │
│   50 │  ╱    ╲╱  ╲              │
│    0 └─────────────────► time   │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  Histogram                      │
│  ────────────────────────       │
│  Distribution de valeurs        │
│  Ex: request_duration           │
│                                 │
│      ▲                          │
│  freq│    ███                   │
│      │  █████                   │
│      │ ███████                  │
│      └─────────────► latency    │
│        p50 p95 p99              │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  Summary                        │
│  ────────────────────────       │
│  Percentiles précalculés        │
│  Ex: quantiles φ(0.5, 0.9, 0.99)│
└─────────────────────────────────┘
```

**Instrumentation flow:**

```
Application
    │
    ├─ httpDuration.Observe(0.234)
    ├─ requestsTotal.Inc()
    ├─ activeConnections.Set(42)
    │
    ▼
Prometheus Client Library
    │
    ▼
/metrics endpoint
    │
    ▼
Prometheus Server (scrape every 15s)
    │
    ▼
Storage (TSDB)
    │
    ▼
Grafana (visualization)
```

**Cardinality:**

```
ATTENTION: Cardinality explosion!

❌ BAD:
http_requests{user_id="12345", ...}
→ Millions de users = Millions de series
→ Prometheus OOM

✓ GOOD:
http_requests{endpoint="/api/users", status="200"}
→ Cardinality limitée
→ Use logging pour user_id
```

### 2. Logs

Événements discrets avec contexte.

**Log Levels:**

```
┌──────────────────────────────────┐
│  Severity Pyramid                │
└──────────────────────────────────┘

         FATAL   ← Service crash
           │
         ERROR   ← Needs immediate attention
           │
          WARN   ← Unexpected but handled
           │
          INFO   ← Normal operations
           │
         DEBUG   ← Development details
           │
         TRACE   ← Ultra-detailed
```

**Structured Logging:**

```
Unstructured (bad):
"User john logged in from 192.168.1.1 at 10:05"
→ Hard to parse, search, aggregate

Structured (good):
{
  "timestamp": "2024-11-30T10:05:00Z",
  "level": "INFO",
  "msg": "user login",
  "user_id": "john",
  "ip": "192.168.1.1",
  "trace_id": "abc123"
}
→ Easy to query, correlate, analyze
```

**Log Pipeline:**

```
Application
    │ (structured logs)
    ▼
Stdout/Stderr
    │
    ▼
Log Collector (Fluent Bit, Fluentd)
    │
    ├─ Parse
    ├─ Enrich (add k8s metadata)
    ├─ Filter
    └─ Buffer
    │
    ▼
Log Storage (Loki, ElasticSearch)
    │
    ▼
Query Interface (Grafana, Kibana)
```

**What to log:**

```
✓ DO Log:
├─ Service start/stop
├─ Significant state changes
├─ External API calls (with duration)
├─ Authentication events
├─ Errors with stack traces
├─ Business events
└─ Request IDs for tracing

✗ DON'T Log:
├─ Sensitive data (passwords, tokens)
├─ High-frequency events (every cache hit)
├─ Redundant info (already in metrics)
└─ Binary data
```

### 3. Traces

Suivi d'une requête à travers tout le système distribué.

**Distributed Trace:**

```
User Request
    │
    ▼
┌─────────────────────────────────────┐
│ API Gateway         [Span A: 245ms] │
└─────────┬──────────┬────────────────┘
          │          │
          ▼          ▼
    ┌─────────┐  ┌──────────┐
    │ Auth    │  │ UserSvc  │
    │[Span B] │  │[Span C]  │
    │  25ms   │  │  180ms   │
    └─────────┘  └────┬─────┘
                      │
                      ▼
                 ┌─────────┐
                 │ DB      │
                 │[Span D] │
                 │  120ms  │
                 └─────────┘

Trace = Collection of Spans
Span = Single operation with start/end
```

**Trace Anatomy:**

```
Trace ID: abc-123-def
│
├─ Span ID: span-1 (API Gateway)
│  ├─ Start: 10:05:00.000
│  ├─ End: 10:05:00.245
│  ├─ Duration: 245ms
│  ├─ Tags: {service: api-gateway, http.method: GET}
│  └─ Children: [span-2, span-3]
│
├─ Span ID: span-2 (Auth Service)
│  ├─ Parent: span-1
│  ├─ Duration: 25ms
│  └─ Tags: {service: auth}
│
└─ Span ID: span-3 (User Service)
   ├─ Parent: span-1
   ├─ Duration: 180ms
   ├─ Children: [span-4]
   └─ Tags: {service: user}
       │
       └─ Span ID: span-4 (Database)
          ├─ Parent: span-3
          ├─ Duration: 120ms
          └─ Tags: {service: postgres, query: SELECT}
```

**Waterfall View:**

```
Time →
0ms        100ms       200ms       300ms

API GW  [═══════════════════════════] 245ms
  │
  ├─Auth [═══] 25ms
  │
  └─User     [═══════════════════] 180ms
       │
       └─DB        [════════] 120ms

Insights:
- Total latency: 245ms
- DB is slowest (120ms)
- User service has 60ms overhead
```

### Correlation

Relier metrics, logs, traces.

```
┌──────────────────────────────────────┐
│     Incident Timeline                │
├──────────────────────────────────────┤
│                                      │
│ 10:05 │ Metrics: p99 latency spike   │
│       │          500ms → 2000ms      │
│       │                              │
│       ▼                              │
│       Search logs with:              │
│       - timestamp ~10:05             │
│       - latency > 1s                 │
│       │                              │
│       ├─ Found trace_id: abc123      │
│       │                              │
│       ▼                              │
│       View trace abc123:             │
│       - DB query: 1.8s (slow!)       │
│       - Query: SELECT * FROM ...     │
│       │                              │
│       ▼                              │
│       Root cause: Missing index      │
│                                      │
└──────────────────────────────────────┘

Flow: Metrics → Logs → Traces → Root Cause
```

**Unified Observability:**

```
Grafana Dashboard
├─ Panel 1: Metrics (Golden Signals)
│  └─ Click anomaly → Filter logs
│
├─ Panel 2: Logs (filtered by time)
│  └─ Click log → Show trace
│
└─ Panel 3: Trace (distributed view)
   └─ Identify slow span

Single pane of glass for troubleshooting
```

### Sampling

Traces peuvent être coûteux - échantillonner intelligemment.

```
┌────────────────────────────────────┐
│      Sampling Strategies           │
├────────────────────────────────────┤
│                                    │
│ 1. Head-based (décision au début)  │
│    Sample 1% of all requests       │
│    ├─ Pro: Simple, low overhead    │
│    └─ Con: Peut rater les erreurs  │
│                                    │
│ 2. Tail-based (décision à la fin)  │
│    Keep all errors + 1% success    │
│    ├─ Pro: Catch all issues        │
│    └─ Con: Complex, more overhead  │
│                                    │
│ 3. Adaptive                        │
│    Increase sampling when errors↑  │
│    ├─ Pro: Best of both            │
│    └─ Con: Most complex            │
│                                    │
└────────────────────────────────────┘
```

## Deployment Strategies

Stratégies pour déployer des changements sans risque.

### 1. Rolling Update

Le défaut dans Kubernetes - remplacement progressif.

```
Initial state:
[v1] [v1] [v1] [v1] [v1]

Step 1: Kill 1 old, start 1 new
[v1] [v1] [v1] [v1] [v2]

Step 2:
[v1] [v1] [v1] [v2] [v2]

Step 3:
[v1] [v1] [v2] [v2] [v2]

Step 4:
[v1] [v2] [v2] [v2] [v2]

Step 5:
[v2] [v2] [v2] [v2] [v2]

Config:
maxUnavailable: 1 (max pods down)
maxSurge: 1 (max extra pods)
```

**Timeline:**

```
Time →
0s     30s    60s    90s    120s   150s

v1: ████████████░░░░░░░░░░░░░░░░░░
v2: ░░░░░░░░░░░░████████████████████

Traffic gradually shifts from v1 to v2
Both versions coexist during rollout
```

### 2. Blue-Green Deployment

Deux environnements identiques - switch instantané.

```
┌─────────────────────────────────┐
│      Before Deployment          │
├─────────────────────────────────┤
│                                 │
│  Load Balancer                  │
│        │                        │
│        ▼                        │
│   Blue (v1) ✓                   │
│   [pod] [pod] [pod]             │
│   100% traffic                  │
│                                 │
│   Green (v2)                    │
│   [pod] [pod] [pod]             │
│   0% traffic (testing only)     │
│                                 │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│      After Switch               │
├─────────────────────────────────┤
│                                 │
│  Load Balancer                  │
│        │                        │
│        ▼                        │
│   Blue (v1)                     │
│   [pod] [pod] [pod]             │
│   0% traffic (kept for rollback)│
│                                 │
│   Green (v2) ✓                  │
│   [pod] [pod] [pod]             │
│   100% traffic                  │
│                                 │
└─────────────────────────────────┘

Rollback: Just switch back to Blue
```

### 3. Canary Deployment

Déploiement progressif avec monitoring.

```
┌────────────────────────────────────┐
│     Canary Progression             │
├────────────────────────────────────┤
│                                    │
│ Phase 1: 5% traffic to canary      │
│ ├─ Monitor for 10 minutes          │
│ ├─ Check error rate, latency       │
│ └─ If OK → continue                │
│                                    │
│ Phase 2: 25% traffic               │
│ ├─ Monitor for 10 minutes          │
│ └─ If OK → continue                │
│                                    │
│ Phase 3: 50% traffic               │
│ ├─ Monitor for 10 minutes          │
│ └─ If OK → continue                │
│                                    │
│ Phase 4: 100% traffic              │
│ └─ Complete migration              │
│                                    │
│ At any point:                      │
│ └─ If metrics degrade → ROLLBACK   │
│                                    │
└────────────────────────────────────┘
```

**Traffic Split Timeline:**

```
% Traffic →
100│                          ████
   │                      ████░░░░
   │                  ████░░░░░░░░
 50│              ████░░░░░░░░░░░░
   │          ████░░░░░░░░░░░░░░░░
   │      ████░░░░░░░░░░░░░░░░░░░░
  0└──────────────────────────────► Time
      0m   10m  20m  30m  40m

    ░ Old version
    █ New version (canary)
```

**Automated Canary with Flagger:**

```
┌──────────────────────────────────────┐
│    Flagger Canary Analysis           │
├──────────────────────────────────────┤
│                                      │
│  Metrics checked:                    │
│  ├─ Request success rate > 99%       │
│  ├─ Request duration p99 < 500ms     │
│  └─ Error rate < 1%                  │
│                                      │
│  Analysis window: 1 minute           │
│  Iterations: 10                      │
│  Step weight: 10%                    │
│                                      │
│  If 5 consecutive failures:          │
│  └─ Automatic rollback               │
│                                      │
└──────────────────────────────────────┘
```

### 4. Feature Flags

Déployer le code mais contrôler l'activation.

```
┌────────────────────────────────────┐
│    Feature Flag Rollout            │
└────────────────────────────────────┘

Deploy v2 with new feature (flag OFF)
    │
    ▼
Enable for 1% of users (internal)
    │
    ├─ Monitor metrics
    ├─ Gather feedback
    │
    ▼
Enable for 10% of users
    │
    ├─ Monitor
    │
    ▼
Enable for 50% of users
    │
    ├─ Monitor
    │
    ▼
Enable for 100% of users
    │
    ▼
Remove flag (cleanup)

Rollback = Just flip flag OFF
(No redeployment needed)
```

**Flag Types:**

```
┌────────────────────────────────┐
│  Release Flags                 │
│  └─ Short-lived, removed       │
│     after full rollout         │
├────────────────────────────────┤
│  Ops Flags                     │
│  └─ Long-lived, control        │
│     system behavior            │
├────────────────────────────────┤
│  Experiment Flags              │
│  └─ A/B testing                │
│     Temporary                  │
└────────────────────────────────┘
```

### Comparison Table

| Strategy      | Speed  | Risk  | Rollback | Resource | Use Case        |
|---------------|--------|-------|----------|----------|-----------------|
| Rolling       | Medium | Low   | Slow     | Low      | Standard        |
| Blue-Green    | Instant| Low   | Instant  | High     | Critical apps   |
| Canary        | Slow   | V.Low | Fast     | Medium   | High-risk       |
| Feature Flags | Instant| V.Low | Instant  | Low      | Experimentation |

## Practical Patterns

### Health Checks

Signaler l'état de l'application à Kubernetes.

```
┌────────────────────────────────────┐
│     Kubernetes Probes              │
└────────────────────────────────────┘

Liveness Probe:
├─ Question: "Is the app alive?"
├─ If fails: Kill & restart pod
├─ Example: /healthz
└─ Check: Basic app responsiveness

Readiness Probe:
├─ Question: "Can it handle traffic?"
├─ If fails: Remove from service endpoints
├─ Example: /ready
└─ Check: Dependencies (DB, cache, etc.)

Startup Probe:
├─ Question: "Has it started?"
├─ If fails: Kill & restart (slow start apps)
├─ Example: /startup
└─ Check: Initial startup complete
```

**Probe Flow:**

```
Pod Starting
    │
    ▼
┌──────────────┐
│Startup Probe │ → Fail → Kill pod
└──────┬───────┘
       │ Pass
       ▼
┌──────────────┐
│Liveness      │ → Fail → Restart pod
│(continuous)  │
└──────┬───────┘
       │ Pass
       ▼
┌──────────────┐
│Readiness     │ → Fail → Remove from endpoints
│(continuous)  │           (but don't kill)
└──────┬───────┘
       │ Pass
       ▼
   Receive traffic
```

**Health Check Logic:**

```
Liveness (/healthz):
└─ Return 200 OK
   Simple, fast check

Readiness (/ready):
├─ Check database connection
├─ Check cache connection  
├─ Check external APIs
└─ If any fails → 503

Don't:
✗ Use liveness for dependency checks
  (causes cascading restarts)
✗ Make health checks too slow (>1s)
✗ Check external services in liveness
```

### Graceful Shutdown

Arrêter proprement sans perdre de requêtes.

```
┌────────────────────────────────────┐
│    Shutdown Sequence               │
└────────────────────────────────────┘

SIGTERM received
    │
    ▼
1. Stop accepting new requests
   └─ Return 503 to load balancer
    │
    ▼
2. Wait for in-flight requests
   └─ Timeout: 30s
    │
    ▼
3. Close connections
   └─ DB, cache, queues
    │
    ▼
4. Flush logs/metrics
    │
    ▼
5. Exit

If > 30s: SIGKILL (forceful)
```

**Kubernetes Lifecycle:**

```
Time →
0s      5s     15s    30s    35s

│       │      │      │      │
│       │      │      │      │
▼       ▼      ▼      ▼      ▼
Deploy  SIGTERM Drain Grace  SIGKILL
        sent    done  period (force)
                      ends

terminationGracePeriodSeconds: 30s
preStop hook: /shutdown
```

### Resource Limits

Contrôler l'utilisation des ressources.

```
┌────────────────────────────────────┐
│    Resource Management             │
├────────────────────────────────────┤
│                                    │
│  Requests (Scheduler garantit):   │
│  ├─ CPU: 100m (0.1 core)          │
│  └─ Memory: 128Mi                  │
│                                    │
│  Limits (Hard cap):                │
│  ├─ CPU: 500m (0.5 core)          │
│  │  └─ Throttled si dépassé       │
│  │                                 │
│  └─ Memory: 512Mi                  │
│     └─ OOMKilled si dépassé       │
│                                    │
└────────────────────────────────────┘
```

**QoS Classes:**

```
Guaranteed (Best):
├─ requests = limits
├─ Lowest eviction priority
└─ Use for critical services

Burstable (Medium):
├─ requests < limits
├─ Medium eviction priority
└─ Use for most apps

BestEffort (Worst):
├─ No requests or limits
├─ First to be evicted
└─ Use for non-critical batch jobs
```

**Resource Patterns:**

```
CPU-bound app:
requests: 
  cpu: 1000m
  memory: 256Mi
limits:
  cpu: 2000m      ← Can burst
  memory: 256Mi   ← Fixed

Memory-bound app:
requests:
  cpu: 100m
  memory: 2Gi
limits:
  cpu: 500m       ← Can burst
  memory: 2Gi     ← Fixed (avoid OOM)
```

### Autoscaling

Adapter automatiquement les ressources.

**HPA (Horizontal Pod Autoscaler):**

```
┌────────────────────────────────────┐
│    HPA Scaling Logic               │
└────────────────────────────────────┘

Current CPU: 80%
Target CPU: 50%
Current pods: 3

Desired pods = ceil(3 × 80/50) = 5

Scale up to 5 pods
    │
    ▼
CPU drops to 40% (below target)
    │
    ▼
Wait stabilization (5min)
    │
    ▼
Desired pods = ceil(5 × 40/50) = 4

Scale down to 4 pods
```

**Scaling Behavior:**

```
Scale Up:
├─ Fast (default: double every 15s)
├─ No stabilization window
└─ React quickly to load spikes

Scale Down:
├─ Slow (default: 1 pod/5min)
├─ Stabilization window: 5min
└─ Prevent flapping
```

**VPA (Vertical Pod Autoscaler):**

```
Monitors resource usage
    │
    ▼
Recommends new requests/limits
    │
    ▼
Can auto-update pods
(requires restart)

Use for:
└─ Apps with variable resource needs
   that can't scale horizontally
```

**KEDA (Event-driven Autoscaling):**

```
Scalers:
├─ Kafka queue depth
├─ RabbitMQ messages
├─ Prometheus metrics
├─ Cron schedules
└─ HTTP requests

Example:
Queue depth > 100 → Scale to 10 pods
Queue depth < 10 → Scale to 1 pod
Queue empty for 5min → Scale to 0
```

## Resiliency Maturity Model

Progression vers une architecture résiliente.

```
┌────────────────────────────────────────────┐
│         Level 0: Reactive                  │
├────────────────────────────────────────────┤
│ • No monitoring                            │
│ • Manual deployments                       │
│ • No health checks                         │
│ • Learn from production outages            │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│         Level 1: Aware                     │
├────────────────────────────────────────────┤
│ • Basic metrics (CPU, memory)              │
│ • Automated deployments                    │
│ • Liveness/readiness probes                │
│ • Some logging                             │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│         Level 2: Proactive                 │
├────────────────────────────────────────────┤
│ • Golden signals monitored                 │
│ • SLOs defined                             │
│ • Structured logging                       │
│ • Alerting on SLO burn rate                │
│ • Circuit breakers                         │
│ • Retry policies                           │
│ • Rolling updates                          │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│         Level 3: Resilient                 │
├────────────────────────────────────────────┤
│ • Distributed tracing                      │
│ • Error budget tracking                    │
│ • Rate limiting                            │
│ • Graceful degradation                     │
│ • Canary deployments                       │
│ • Chaos engineering (staging)              │
│ • Runbooks for common incidents            │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│         Level 4: Antifragile               │
├────────────────────────────────────────────┤
│ • Production chaos engineering             │
│ • Automatic remediation                    │
│ • AI-driven anomaly detection              │
│ • Self-healing systems                     │
│ • Game days culture                        │
│ • Continuous improvement from incidents    │
└────────────────────────────────────────────┘
```

## Incident Response Flow

```
┌────────────────────────────────────────────┐
│         Incident Lifecycle                 │
└────────────────────────────────────────────┘

1. DETECTION
   ├─ Alert fires (burn rate, error spike)
   ├─ On-call engineer notified
   └─ Severity assessed
       │
       ▼
2. TRIAGE
   ├─ Check dashboards (metrics, logs, traces)
   ├─ Identify affected services
   ├─ Determine scope (users impacted)
   └─ Page additional help if needed
       │
       ▼
3. MITIGATION
   ├─ Implement quick fix (rollback, scale, etc.)
   ├─ NOT root cause fix (yet)
   └─ Goal: Restore service ASAP
       │
       ▼
4. COMMUNICATION
   ├─ Update status page
   ├─ Notify stakeholders
   └─ Regular updates every 30min
       │
       ▼
5. RESOLUTION
   ├─ Service restored
   ├─ Monitoring stabilization
   └─ All-clear declared
       │
       ▼
6. POST-MORTEM (within 48h)
   ├─ Timeline of events
   ├─ Root cause analysis
   ├─ What went well
   ├─ What went wrong
   └─ Action items (with owners)
       │
       ▼
7. FOLLOW-UP
   ├─ Implement action items
   ├─ Update runbooks
   └─ Share learnings team-wide
```

## Checklist

### Pre-Production

```
Observability:
☐ Golden signals dashboards
☐ Distributed tracing configured
☐ Structured logging implemented
☐ Alerts on SLO burn rate
☐ Runbooks for common scenarios

Resilience Patterns:
☐ Circuit breakers on external deps
☐ Retry logic with exp backoff
☐ Rate limiting configured
☐ Timeouts on all external calls
☐ Graceful degradation plan

Kubernetes Config:
☐ Liveness probe configured
☐ Readiness probe configured
☐ Resource requests/limits set
☐ HPA configured
☐ PodDisruptionBudget defined

Deployment:
☐ Canary/Blue-Green strategy
☐ Rollback plan documented
☐ Feature flags for risky changes
☐ Database migrations backward-compatible

SLOs:
☐ SLOs defined and documented
☐ Error budget calculated
☐ Stakeholders aligned on targets
```

### Continuous Operations

```
☐ Weekly SLO review
☐ Monthly error budget review
☐ Quarterly game day
☐ Post-mortem for all P1 incidents
☐ Regular chaos experiments
☐ Dashboard accuracy checks
☐ Alert fatigue assessment
☐ Runbook updates after incidents
```

### Post-Incident

```
☐ Timeline documented
☐ Root cause identified
☐ Impact quantified
☐ Action items created
☐ Runbook updated
☐ Team debrief completed
☐ Learnings shared
```

## Resources

### Books
- **Site Reliability Engineering** (Google)
    - Bible du SRE, SLOs, error budgets
- **The DevOps Handbook**
    - Culture, pratiques, études de cas
- **Release It!** (Michael Nygard)
    - Patterns de résilience
- **Chaos Engineering** (Netflix)
    - Guide pratique du chaos

### Tools Ecosystem

```
┌─────────────────────────────────────┐
│         Observability Stack         │
├─────────────────────────────────────┤
│ Metrics:  Prometheus, Grafana       │
│ Logs:     Loki, Fluentd             │
│ Traces:   Jaeger, Tempo, Zipkin     │
│ APM:      OpenTelemetry             │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│         Chaos Engineering           │
├─────────────────────────────────────┤
│ K8s:      Chaos Mesh, Litmus        │
│ Network:  Toxiproxy                 │
│ AWS:      AWS FIS                   │
│ GCP:      Chaos Toolkit             │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│         Progressive Delivery        │
├─────────────────────────────────────┤
│ Canary:   Flagger, Argo Rollouts    │
│ Flags:    Unleash, LaunchDarkly     │
│ Traffic:  Istio, Linkerd            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│         Policy & Governance         │
├─────────────────────────────────────┤
│ Policy:   Kyverno, OPA/Gatekeeper   │
│ Security: Falco, Trivy              │
│ Cost:     Kubecost                  │
└─────────────────────────────────────┘
```

### Standards
- **OpenTelemetry** - Observability standard
- **OpenMetrics** - Metrics exposition
- **CloudEvents** - Event format
- **CNCF Landscape** - Ecosystem map

### Learning Resources
- **SRE Book** (free): sre.google/books
- **OpenTelemetry Docs**: opentelemetry.io
- **Chaos Mesh Docs**: chaos-mesh.org
- **Kyverno Docs**: kyverno.io
- **CNCF YouTube**: Cloud native patterns & talks

---

**Remember:**

> "Hope is not a strategy. Design for failure."

Les systèmes résilients ne sont pas ceux qui ne tombent jamais en panne, mais ceux qui savent comment gérer les pannes quand elles arrivent.
