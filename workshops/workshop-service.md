# Lab GKE Pods et Services

## Objectif
Déployer une application web simple avec des images publiques qui fonctionnent vraiment.

---

## Étape 1 : Préparer le cluster

```bash
# Vérifier
kubectl get nodes
```

---

## Étape 2 : Déployer Nginx (serveur web)

### 2.1 Pod Nginx
```yaml
# nginx-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-server
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
kubectl apply -f nginx-pod.yaml
kubectl apply -f nginx-service.yaml
```

---

## Étape 3 : Déployer Apache (autre serveur web)

### 3.1 Pod Apache
```yaml
# apache-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apache-server
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
kubectl apply -f apache-pod.yaml
kubectl apply -f apache-service.yaml
```

---

## Étape 4 : Déployer WordPress + MySQL

### 4.1 Pod MySQL
```yaml
# mysql-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-db
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

### 4.3 Pod WordPress
```yaml
# wordpress-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: wordpress-site
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
kubectl apply -f mysql-pod.yaml
kubectl apply -f mysql-service.yaml
kubectl apply -f wordpress-pod.yaml
kubectl apply -f wordpress-service.yaml
```

---

## Étape 5 : Vérifier et tester

### 5.1 Voir tous les pods et services
```bash
kubectl get pods
kubectl get services
```

### 5.2 Attendre les IP externes
```bash
# Surveiller les services LoadBalancer
kubectl get services --watch

# Ou vérifier périodiquement
kubectl get service web-service
kubectl get service apache-service
kubectl get service wordpress-service
```

### 5.3 Accéder aux applications
```bash
# Obtenir les URLs
echo "Nginx: http://$(kubectl get service web-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "Apache: http://$(kubectl get service apache-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "WordPress: http://$(kubectl get service wordpress-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

---

## Étape 6 : Tests de connectivité

### 6.1 Tester la communication interne
```bash
# Créer un pod temporaire
kubectl run test-pod --image=busybox --rm -it --restart=Never -- /bin/sh

# Dans le pod de test :
# nslookup mysql-service
# nslookup web-service
# wget -qO- web-service
```

### 6.2 Examiner les pods
```bash
# Logs des pods
kubectl logs web-server
kubectl logs mysql-db
kubectl logs wordpress-site

# Détails d'un pod
kubectl describe pod wordpress-site

# Entrer dans un pod
kubectl exec -it web-server -- /bin/bash
```

---

## Étape 7 : Explorer les services

### 7.1 Types de services
```bash
# ClusterIP (interne seulement)
kubectl get service mysql-service

# LoadBalancer (externe)
kubectl get service wordpress-service

# Voir les endpoints
kubectl get endpoints
```

### 7.2 Détails des services
```bash
kubectl describe service wordpress-service
kubectl describe service mysql-service
```

---

## Nettoyage

```bash
# Supprimer tous les objets
kubectl delete pod --all
kubectl delete service --all
