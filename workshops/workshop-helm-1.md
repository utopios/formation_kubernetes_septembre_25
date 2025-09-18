# Workshop Helm 1

## Objectif

* Comprendre la logique des charts Helm et leur rôle dans Kubernetes.
* Installer, personnaliser et mettre à jour une application avec Helm.


---

## Pré-requis

* Kubernetes fonctionnel .
* kubectl configuré et fonctionnel.
* Helm installé (`helm version`).

---

## Étape 1 – Découverte et installation d’un chart

1. Ajouter un dépôt officiel Helm :

   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   ```
2. Chercher un chart (exemple : Apache) :

   ```bash
   helm search repo apache
   ```
3. Installer une release :

   ```bash
   helm install my-apache bitnami/apache
   ```
4. Vérifier la release :

   ```bash
   helm list
   kubectl get all
   ```

---

## Étape 2 – Exploration des valeurs possibles

1. Voir les valeurs par défaut d’un chart :

   ```bash
   helm show values bitnami/apache > values.yaml
   ```
2. Personnaliser `values.yaml` (changer le service type, le nombre de replicas, les ressources).
3. Réinstaller avec les valeurs modifiées :

   ```bash
   helm upgrade my-apache bitnami/apache -f values.yaml
   ```

---

## Étape 3 – Gestion des versions et des releases

1. Afficher l’historique :

   ```bash
   helm history my-apache
   ```
2. Faire un rollback :

   ```bash
   helm rollback my-apache 1
   ```
3. Supprimer une release :

   ```bash
   helm uninstall my-apache
   ```


