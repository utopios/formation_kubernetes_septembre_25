# Lab - Contrôleurs (Deployments et ReplicaSets)

## Objectif
Transformer les pods simples en utilisant des contrôleurs pour la haute disponibilité et la scalabilité.

---

## Étape 1 : Préparer le cluster

```bash
# Vérifier le cluster
kubectl get nodes
```

---

## Étape 2 : Déployer Nginx avec un Deployment

### 2.1 Deployment Nginx
```yaml
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

### 2.2 Service Nginx (externe)
```yaml
# nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

**Déployer :**
```bash
kubectl apply -f nginx-deployment.yaml
kubectl apply -f nginx-service.yaml
```

---

## Étape 3 : Déployer Apache avec un Deployment

### 3.1 Deployment Apache
```yaml
# apache-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache-deployment
  labels:
    app: apache
spec:
  replicas: 2
  selector:
    matchLabels:
      app: apache
  template:
    metadata:
      labels:
        app: apache
    spec:
      containers:
      - name: apache
        image: httpd:latest
        ports:
        - containerPort: 80
```

### 3.2 Service Apache (externe)
```yaml
# apache-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: apache-service
spec:
  selector:
    app: apache
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

**Déployer :**
```bash
kubectl apply -f apache-deployment.yaml
kubectl apply -f apache-service.yaml
```

---

## Étape 4 : Déployer WordPress + MySQL avec des Deployments

### 4.1 Deployment MySQL
```yaml
# mysql-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-deployment
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "motdepasse123"
        - name: MYSQL_DATABASE
          value: "wordpress"
        - name: MYSQL_USER
          value: "wpuser"
        - name: MYSQL_PASSWORD
          value: "wppass"
```

### 4.2 Service MySQL (interne seulement)
```yaml
# mysql-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
```

### 4.3 Deployment WordPress
```yaml
# wordpress-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-deployment
  labels:
    app: wordpress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          value: "mysql-service:3306"
        - name: WORDPRESS_DB_NAME
          value: "wordpress"
        - name: WORDPRESS_DB_USER
          value: "wpuser"
        - name: WORDPRESS_DB_PASSWORD
          value: "wppass"
```

### 4.4 Service WordPress (externe)
```yaml
# wordpress-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress-service
spec:
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

**Déployer :**
```bash
kubectl apply -f mysql-deployment.yaml
kubectl apply -f mysql-service.yaml
kubectl apply -f wordpress-deployment.yaml
kubectl apply -f wordpress-service.yaml
```

---

## Étape 5 : Explorer les Deployments et ReplicaSets

### 5.1 Voir les ressources créées
```bash
# Voir tous les deployments
kubectl get deployments

# Voir tous les replicasets
kubectl get replicasets

# Voir tous les pods
kubectl get pods

# Voir les services
kubectl get services
```

### 5.2 Détails des deployments
```bash
# Détails du deployment nginx
kubectl describe deployment web-deployment

# Historique du deployment
kubectl rollout history deployment web-deployment

# Statut du rollout
kubectl rollout status deployment web-deployment
```

---

## Étape 6 : Tester la résilience

### 6.1 Supprimer un pod et observer la récréation
```bash
# Lister les pods nginx
kubectl get pods -l app=nginx

# Supprimer un pod nginx (remplacer POD_NAME par un vrai nom)
kubectl delete pod <POD_NAME>

# Observer que le deployment recrée automatiquement le pod
kubectl get pods -l app=nginx --watch
```

### 6.2 Tester la montée en charge
```bash
# Scaler le deployment nginx à 5 replicas
kubectl scale deployment web-deployment --replicas=5

# Observer les nouveaux pods
kubectl get pods -l app=nginx

# Redescendre à 3 replicas
kubectl scale deployment web-deployment --replicas=3
```

---

## Étape 7 : Mise à jour des applications

### 7.1 Mise à jour rolling d'nginx
```bash
# Changer l'image nginx vers une version spécifique
kubectl set image deployment/web-deployment nginx=nginx:1.21

# Observer le rolling update
kubectl rollout status deployment web-deployment

# Voir l'historique
kubectl rollout history deployment web-deployment
```

### 7.2 Rollback en cas de problème
```bash
# Si besoin, revenir à la version précédente
kubectl rollout undo deployment web-deployment

# Ou revenir à une révision spécifique
kubectl rollout undo deployment web-deployment --to-revision=1
```

---

## Étape 8 : Accéder aux applications

### 8.1 Obtenir les URLs externes
```bash
# Attendre que les LoadBalancer aient des IP externes
kubectl get services --watch

# Obtenir les URLs
echo "Nginx: http://$(kubectl get service web-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "Apache: http://$(kubectl get service apache-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "WordPress: http://$(kubectl get service wordpress-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

---

## Exercices pratiques

### Exercice 1 : Test de résilience
1. Supprimez un pod WordPress
2. Vérifiez qu'il est recréé automatiquement
3. Testez que le site continue à fonctionner

### Exercice 2 : Scalabilité
1. Augmentez WordPress à 4 replicas
2. Testez la répartition de charge
3. Réduisez à 1 replica

### Exercice 3 : Mise à jour
1. Changez l'image Apache vers `httpd:2.4-alpine`
2. Observez le rolling update
3. Revenez à la version précédente


---

## Nettoyage

```bash
# Supprimer tous les deployments (supprime automatiquement pods et replicasets)
kubectl delete deployment --all

# Supprimer tous les services
kubectl delete service --all
```