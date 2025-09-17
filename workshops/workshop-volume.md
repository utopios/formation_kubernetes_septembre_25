# Workshop - Volumes et Stockage Persistant

## Objectif
Apprendre à gérer le stockage dans Kubernetes avec différents types de volumes pour persister les données.

---

## Étape 1 : Préparer le cluster

```bash
# Vérifier le cluster
kubectl get nodes

# Voir les classes de stockage disponibles sur GKE
kubectl get storageclass
```

---

## Étape 2 : Volume EmptyDir (stockage temporaire)

### 2.1 Pod avec volume EmptyDir
```yaml
# nginx-emptydir.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-emptydir
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: cache-volume
      mountPath: /tmp/cache
    - name: logs-volume
      mountPath: /var/log/nginx
  - name: log-reader
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Reading logs...'; tail -f /var/log/nginx/access.log 2>/dev/null || sleep 5; done"]
    volumeMounts:
    - name: logs-volume
      mountPath: /var/log/nginx
  volumes:
  - name: cache-volume
    emptyDir: {}
  - name: logs-volume
    emptyDir: {}
```

**Déployer et tester :**
```bash
kubectl apply -f nginx-emptydir.yaml

# Voir les volumes montés
kubectl describe pod nginx-emptydir

# Tester le partage de volumes entre conteneurs
kubectl exec -it nginx-emptydir -c nginx -- /bin/bash
# Dans le conteneur nginx :
# echo "Test data" > /tmp/cache/test.txt
# echo "127.0.0.1 - - [$(date)] GET / HTTP/1.1 200" >> /var/log/nginx/access.log

# Vérifier depuis l'autre conteneur
kubectl exec -it nginx-emptydir -c log-reader -- cat /var/log/nginx/access.log
```

---

## Étape 3 : PersistentVolume et PersistentVolumeClaim

### 3.1 PersistentVolumeClaim pour MySQL
```yaml
# mysql-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard-rwo
```

### 3.2 Deployment MySQL avec volume persistant
```yaml
# mysql-persistent.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-persistent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-persistent
  template:
    metadata:
      labels:
        app: mysql-persistent
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpassword"
        - name: MYSQL_DATABASE
          value: "testdb"
        - name: MYSQL_USER
          value: "testuser"
        - name: MYSQL_PASSWORD
          value: "testpass"
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
```

### 3.3 Service MySQL
```yaml
# mysql-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
spec:
  selector:
    app: mysql-persistent
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
```

**Déployer :**
```bash
kubectl apply -f mysql-pvc.yaml
kubectl apply -f mysql-persistent.yaml
kubectl apply -f mysql-service.yaml

# Vérifier le PVC
kubectl get pvc
kubectl describe pvc mysql-pvc

# Vérifier le PV créé automatiquement
kubectl get pv
```

---

## Étape 4 : Application avec données persistantes

### 4.1 PVC pour WordPress
```yaml
# wordpress-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard-rwo
```

### 4.2 Deployment WordPress avec volume
```yaml
# wordpress-persistent.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-persistent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress-persistent
  template:
    metadata:
      labels:
        app: wordpress-persistent
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          value: mysql-service:3306
        - name: WORDPRESS_DB_NAME
          value: testdb
        - name: WORDPRESS_DB_USER
          value: testuser
        - name: WORDPRESS_DB_PASSWORD
          value: testpass
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc
```

### 4.3 Service WordPress
```yaml
# wordpress-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress-service
spec:
  selector:
    app: wordpress-persistent
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

**Déployer :**
```bash
kubectl apply -f wordpress-pvc.yaml
kubectl apply -f wordpress-persistent.yaml
kubectl apply -f wordpress-service.yaml

# Attendre que WordPress soit prêt
kubectl get pods -w
```

---

## Étape 5 : Volume ConfigMap (configuration)

### 5.1 ConfigMap avec configuration nginx
```yaml
# nginx-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /api {
            return 200 "API endpoint working!\n";
            add_header Content-Type text/plain;
        }
    }
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Configuration depuis ConfigMap</title></head>
    <body>
        <h1>Nginx configuré avec ConfigMap</h1>
        <p>Cette page est servie par une configuration dans un ConfigMap</p>
        <a href="/api">Tester l'API</a>
    </body>
    </html>
```

### 5.2 Pod nginx avec ConfigMap
```yaml
# nginx-configmap.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-configmap
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d/default.conf
      subPath: nginx.conf
    - name: html-volume
      mountPath: /usr/share/nginx/html/index.html
      subPath: index.html
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
  - name: html-volume
    configMap:
      name: nginx-config
```

**Déployer et tester :**
```bash
kubectl apply -f nginx-config.yaml
kubectl apply -f nginx-configmap.yaml

# Exposer temporairement pour tester
kubectl port-forward pod/nginx-configmap 8080:80

# Dans un autre terminal, tester
curl http://localhost:8080
curl http://localhost:8080/api
```

---

## Étape 6 : Volume Secret (données sensibles)

### 6.1 Secret pour base de données
```yaml
# db-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=        # admin en base64
  password: cGFzc3dvcmQxMjM= # password123 en base64
  config.properties: |
    ZGJfdXJsPWpkYmM6bXlzcWw6Ly9teXNxbC1zZXJ2aWNlOjMzMDYvdGVzdGRiCmRiX3VzZXI9YWRtaW4KZGJ fcGFzc3dvcmQ9cGFzc3dvcmQxMjM=
  # Contenu en base64 : db_url=jdbc:mysql://mysql-service:3306/testdb\ndb_user=admin\ndb_password=password123
```

### 6.2 Pod utilisant le Secret
```yaml
# app-with-secret.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secret
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'App running...'; cat /etc/secrets/config.properties; sleep 30; done"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-secret
```

**Déployer et vérifier :**
```bash
kubectl apply -f db-secret.yaml
kubectl apply -f app-with-secret.yaml

# Vérifier que les secrets sont montés
kubectl exec -it app-with-secret -- ls -la /etc/secrets/
kubectl exec -it app-with-secret -- cat /etc/secrets/username
kubectl exec -it app-with-secret -- sh
echo $DB_USER
# kubectl exec -it app-with-secret -- echo $DB_USER
```

---

## Étape 7 : Tester la persistance des données

### 7.1 Ajouter des données à WordPress
```bash
# Obtenir l'IP externe de WordPress
kubectl get service wordpress-service

# Ouvrir WordPress dans le navigateur
echo "WordPress: http://$(kubectl get service wordpress-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

# Configurer WordPress et créer du contenu
```

### 7.2 Tester la persistance
```bash
# Supprimer le pod WordPress
kubectl delete pod -l app=wordpress-persistent

# Attendre qu'un nouveau pod soit créé
kubectl get pods -w

# Vérifier que les données sont toujours là
# (retourner sur l'IP WordPress)
```

### 7.3 Examiner les volumes
```bash
# Voir les PVC et leur utilisation
kubectl get pvc

# Détails d'un PVC
kubectl describe pvc wordpress-pvc

# Voir les PV créés par GKE
kubectl get pv

# Voir l'utilisation de l'espace disque dans le pod
kubectl exec -it $(kubectl get pod -l app=wordpress-persistent -o jsonpath='{.items[0].metadata.name}') -- df -h
```

---

## Étape 8 : Volume HostPath (développement uniquement)

### 8.1 Pod avec HostPath
```yaml
# nginx-hostpath.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-hostpath
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: host-volume
      mountPath: /usr/share/nginx/html
  volumes:
  - name: host-volume
    hostPath:
      path: /tmp/nginx-data
      type: DirectoryOrCreate
```

**⚠️ Note :** HostPath n'est pas recommandé en production !

```bash
kubectl apply -f nginx-hostpath.yaml

# Le répertoire sera créé sur le nœud où s'exécute le pod
kubectl describe pod nginx-hostpath
```

---

## Étape 9 : Backup et restauration

### 9.1 Créer un snapshot des données
```bash
# Lister les PV pour voir les détails du disque
kubectl get pv

# Dans GCP Console, créer un snapshot du disque persistent
# Ou via gcloud :
# gcloud compute disks snapshot DISK_NAME --snapshot-names=mysql-backup-$(date +%Y%m%d)
```

### 9.2 Vérifier l'utilisation des volumes
```bash
# Voir l'espace utilisé dans MySQL
kubectl exec -it $(kubectl get pod -l app=mysql-persistent -o jsonpath='{.items[0].metadata.name}') -- df -h /var/lib/mysql

# Voir l'espace utilisé dans WordPress
kubectl exec -it $(kubectl get pod -l app=wordpress-persistent -o jsonpath='{.items[0].metadata.name}') -- du -sh /var/www/html
```

---

## Nettoyage

```bash
# Supprimer les ressources (ATTENTION : les PVC et données seront perdues)
kubectl delete deployment --all
kubectl delete pod --all
kubectl delete service --all
kubectl delete configmap --all
kubectl delete secret --all

# Supprimer les PVC (supprime définitivement les données)
kubectl delete pvc --all

# Vérifier que les PV sont aussi supprimés
kubectl get pv
```