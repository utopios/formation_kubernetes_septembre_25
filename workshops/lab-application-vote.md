# Lab GKE - Application de Vote

## Objectif
Déployer une application de vote complète sur GKE en utilisant uniquement des pods et services.

## Schéma de l'application

```
┌─────────────────┐    ┌─────────────────┐
│   VOTE UI       │    │   RESULT UI     │
│ (interface web) │    │ (interface web) │
│ Port: 80        │    │ Port: 80        │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          │ HTTP                 │ HTTP
          │                      │
┌─────────▼───────┐    ┌─────────▼───────┐
│   VOTE API      │    │   RESULT API    │
│ (backend vote)  │    │ (backend result)│
│ Port: 80        │    │ Port: 80        │
└─────────┬───────┘    └─────────▲───────┘
          │                      │
          │ Redis                │ PostgreSQL
          │                      │
          ▼                      │
    ┌──────────┐       ┌─────────┴───────┐
    │  REDIS   │◄──────┤     WORKER      │
    │ Port:6379│       │  (traite votes) │
    └──────────┘       └─────────────────┘
                                 │
                                 ▼
                         ┌─────────────┐
                         │ POSTGRESQL  │
                         │ Port: 5432  │
                         └─────────────┘
```

## Architecture de l'application

**Frontend (Interfaces utilisateur) :**
- `mohamed1780/vote-ui` : Interface web pour voter
- `mohamed1780/result-ui` : Interface web pour voir les résultats

**Backend (APIs) :**
- `mohamed1780/vote` : API qui gère les votes
- `mohamed1780/result` : API qui affiche les résultats

**Services de données :**
- `mohamed1780/worker` : Service qui transfère les votes de Redis vers PostgreSQL
- `redis:alpine` : Base de données temporaire (stockage des votes)
- `postgres:15-alpine` : Base de données permanente (résultats finaux)

## Flux de données

1. **Utilisateur vote** → `vote-ui` → `vote` API → `redis`
2. **Worker** lit `redis` → traite → écrit dans `postgres`
3. **Utilisateur consulte** → `result-ui` → `result` API → `postgres`

---

## Mission

Déployez cette application complète sur votre cluster GKE en créant :

### Étape 1 : Préparation
- Créer un cluster GKE avec 3 nœuds
- Se connecter au cluster

### Étape 2 : Base de données Redis
- Déployer Redis avec l'image `redis:alpine`
- Exposer avec un service ClusterIP sur le port 6379
- Nommer le service `redis`

### Étape 3 : Base de données PostgreSQL
- Déployer PostgreSQL avec l'image `postgres:15-alpine`
- Configurer les variables d'environnement :
  - `POSTGRES_USER: postgres`
  - `POSTGRES_PASSWORD: postgres`
- Exposer avec un service ClusterIP sur le port 5432
- Nommer le service `db`

### Étape 4 : API Vote
- Déployer avec l'image `mohamed1780/vote`
- Exposer sur le port 80
- Créer un service ClusterIP nommé `vote`

### Étape 5 : Interface Vote
- Déployer avec l'image `mohamed1780/vote-ui`
- Exposer sur le port 80
- Créer un service LoadBalancer pour l'accès externe

### Étape 6 : Worker
- Déployer avec l'image `mohamed1780/worker`
- Pas besoin de service (le worker ne reçoit pas de requêtes)

### Étape 7 : API Result
- Déployer avec l'image `mohamed1780/result`
- Exposer sur le port 80
- Créer un service ClusterIP nommé `result`

### Étape 8 : Interface Result
- Déployer avec l'image `mohamed1780/result-ui`
- Exposer sur le port 80
- Créer un service LoadBalancer pour l'accès externe

### Étape 9 : Tests
- Vérifier que tous les pods sont en état `Running`
- Obtenir les IP externes des LoadBalancer
- Tester l'application de vote
- Tester l'affichage des résultats

---

## Conseils

**Nommage :**
- Utilisez des noms cohérents pour vos pods et services
- Les services doivent avoir des noms spécifiques pour la communication inter-pods

**Types de services :**
- **ClusterIP** : Pour la communication interne (redis, db, APIs)
- **LoadBalancer** : Pour l'accès externe (interfaces utilisateur)

**Communication :**
- Les pods communiquent via les noms des services

**Variables d'environnement :**
- PostgreSQL nécessite `POSTGRES_USER` et `POSTGRES_PASSWORD`
- Certaines images peuvent nécessiter des variables pour se connecter aux services

**Ordre de déploiement :**
1. Commencez par les bases de données (Redis, PostgreSQL)
2. Déployez les APIs (vote, result)
3. Déployez le worker
4. Finissez par les interfaces utilisateur

---

## Résultat attendu

À la fin du lab, vous devriez avoir :
- Une interface de vote accessible depuis l'extérieur
- Une interface de résultats accessible depuis l'extérieur

**Testez votre application :**
1. Votez sur l'interface de vote


---

## Questions de réflexion

1. Pourquoi utilise-t-on ClusterIP pour les APIs et LoadBalancer pour les UI ?
2. Quel est le rôle du worker dans cette architecture ?
3. Que se passe-t-il si le pod worker s'arrête ?
4. Comment les pods communiquent-ils entre eux ?