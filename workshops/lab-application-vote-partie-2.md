# Lab GKE - Sécurisation de l'Application de Vote

## Objectif
Reprendre l'application de vote déployée précédemment et la sécuriser selon les bonnes pratiques Kubernetes.

## Prérequis
Avoir terminé le lab précédent avec l'application de vote fonctionnelle.

---

## Mission : Sécuriser l'application existante



### Réorganisation par namespaces
- Créer des namespaces dédiés : `vote-frontend`, `vote-backend`, `vote-data`
- Appliquer les Pod Security Standards appropriés à chaque namespace
- Redistribuer les composants dans leurs namespaces respectifs

### Intégration des volumes sécurisés

### Persistance des données
- **PostgreSQL** : Créer un PVC pour persister les données de vote
- **Configuration** : Utiliser des ConfigMaps pour les configurations applicatives

###  RBAC (Role-Based Access Control)
- Créer des ServiceAccounts spécifiques pour chaque composant
- Définir des rôles avec permissions minimales
- Appliquer le principe du moindre privilège

### Sécurisation des secrets
- Créer des Secrets Kubernetes pour les mots de passe PostgreSQL
- Supprimer les mots de passe en dur des variables d'environnement
- Monter les secrets de manière sécurisée dans les pods

### Security Contexts
- Configurer tous les pods pour ne pas tourner en root
- Activer `readOnlyRootFilesystem` où possible
- Désactiver l'escalade de privilèges
- Supprimer toutes les capabilities inutiles

### Network Policies
- Implémenter l'isolation réseau entre les tiers
- Autoriser uniquement les communications nécessaires :
  - Frontend → Backend
  - Backend → Base de données
  - Bloquer les communications non autorisées

