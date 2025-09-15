# Lab Kubernetes - Pods Multi-Conteneurs 

## Exercice 1 : Premier Pod Multi-Conteneurs

### Objectif : Créer un pod avec 2 conteneurs qui partagent des données

### Étape 1 : Créer le fichier pod
```yaml
# pod-multi-simple.yaml
apiVersion: v1
kind: Pod
metadata:
  name: mon-premier-pod-multi
spec:
  containers:
  # Premier conteneur : écrit des données
  - name: writer
    image: busybox
    command: 
    - sh
    - -c
    - |
      while true; do
        echo "Message écrit à $(date)" >> /shared/messages.txt
        sleep 5
      done
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  
  # Deuxième conteneur : lit les données
  - name: reader
    image: busybox
    command:
    - sh
    - -c
    - |
      while true; do
        echo "=== Contenu du fichier ==="
        cat /shared/messages.txt 2>/dev/null || echo "Fichier pas encore créé"
        echo "========================="
        sleep 10
      done
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  
  volumes:
  - name: shared-volume
    emptyDir: {}
```

### Étape 2 : Déployer et observer
```bash
# Créer le pod
kubectl apply -f pod-multi-simple.yaml

# Vérifier que le pod est créé
kubectl get pods

# Voir les détails du pod
kubectl describe pod mon-premier-pod-multi

# Voir les logs du conteneur writer
kubectl logs mon-premier-pod-multi -c writer

# Voir les logs du conteneur reader
kubectl logs mon-premier-pod-multi -c reader

# Suivre les logs en temps réel
kubectl logs mon-premier-pod-multi -c reader -f
```

### Questions :
1. Combien de conteneurs voyez-vous dans le pod ?
2. Que fait chaque conteneur ?
3. Comment les conteneurs partagent-ils les données ?

---

## Exercice 2 : Communication via Network (localhost)

### Objectif : Montrer que les conteneurs partagent la même IP

### Étape 1 : Pod avec serveur web et client
```yaml
# pod-network-sharing.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-network-demo
spec:
  containers:
  # Conteneur serveur web
  - name: web-server
    image: nginx:1.21
    ports:
    - containerPort: 80
  
  # Conteneur client qui teste le serveur
  - name: web-client
    image: busybox
    command:
    - sh
    - -c
    - |
      while true; do
        echo "=== Test de connexion au serveur web ==="
        wget -q -O- http://localhost:80 || echo "Connexion échouée"
        echo "======================================="
        sleep 15
      done
```

### Étape 2 : Tester la communication
```bash
# Créer le pod
kubectl apply -f pod-network-sharing.yaml

# Attendre que le pod soit prêt
kubectl wait --for=condition=Ready pod/pod-network-demo

# Voir les logs du client
kubectl logs pod-network-demo -c web-client -f

# Se connecter au pod pour tester manuellement
kubectl exec -it pod-network-demo -c web-client -- sh

# Dans le shell du conteneur :
# wget -q -O- http://localhost:80
# exit
```

### Questions :
1. Le client peut-il accéder au serveur via `localhost` ?
2. Que se passe-t-il si vous changez `localhost` par l'IP du pod ?

---

## Exercice 3 : Pattern Sidecar Simple

### Objectif : Un conteneur principal avec un conteneur d'aide

### Étape 1 : Application avec monitoring
```yaml
# pod-sidecar-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-avec-sidecar
spec:
  containers:
  # Application principale
  - name: main-app
    image: busybox
    command:
    - sh
    - -c
    - |
      while true; do
        echo "$(date): Application en cours d'exécution" >> /var/log/app.log
        echo "$(date): Traitement de $(($RANDOM % 100)) éléments" >> /var/log/app.log
        sleep 8
      done
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  
  # Sidecar qui surveille les logs
  - name: log-monitor
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Démarrage du monitoring des logs..."
      while true; do
        echo "=== MONITORING DES LOGS ==="
        tail -5 /var/log/app.log 2>/dev/null || echo "Logs pas encore disponibles"
        echo "=========================="
        sleep 12
      done
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  
  volumes:
  - name: log-volume
    emptyDir: {}
```

### Étape 2 : Observer le pattern sidecar
```bash
# Créer le pod
kubectl apply -f pod-sidecar-demo.yaml

# Voir les logs de l'application principale
kubectl logs app-avec-sidecar -c main-app

# Voir les logs du sidecar monitor
kubectl logs app-avec-sidecar -c log-monitor -f

# Exécuter des commandes dans chaque conteneur
kubectl exec -it app-avec-sidecar -c main-app -- ls -la /var/log/
kubectl exec -it app-avec-sidecar -c log-monitor -- cat /var/log/app.log
```

---

## Exercice 4 : Pattern Init Container

### Objectif : Préparer l'environnement avant le démarrage des conteneurs principaux

### Étape 1 : Pod avec préparation
```yaml
# pod-init-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-avec-init
spec:
  # Conteneurs d'initialisation (s'exécutent avant les conteneurs principaux)
  initContainers:
  - name: setup-config
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "=== Préparation de la configuration ==="
      echo "app_name=MonApp" > /shared/config.txt
      echo "version=1.0" >> /shared/config.txt
      echo "env=development" >> /shared/config.txt
      echo "Configuration créée avec succès !"
    volumeMounts:
    - name: config-volume
      mountPath: /shared
  
  - name: setup-data
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "=== Préparation des données ==="
      mkdir -p /data/users
      echo "user1,Alice,alice@example.com" > /data/users/users.csv
      echo "user2,Bob,bob@example.com" >> /data/users/users.csv
      echo "Données créées avec succès !"
    volumeMounts:
    - name: data-volume
      mountPath: /data
  
  # Conteneurs principaux (s'exécutent après les init containers)
  containers:
  - name: main-application
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "=== Démarrage de l'application ==="
      echo "Configuration trouvée :"
      cat /app/config/config.txt
      echo ""
      echo "Données trouvées :"
      cat /app/data/users/users.csv
      echo ""
      echo "Application démarrée avec succès !"
      while true; do sleep 30; done
    volumeMounts:
    - name: config-volume
      mountPath: /app/config
    - name: data-volume
      mountPath: /app/data
  
  volumes:
  - name: config-volume
    emptyDir: {}
  - name: data-volume
    emptyDir: {}
```

### Étape 2 : Observer les phases d'initialisation
```bash
# Créer le pod
kubectl apply -f pod-init-demo.yaml

# Observer la progression (les init containers s'exécutent en premier)
kubectl get pod pod-avec-init -w

# Voir les logs des init containers
kubectl logs pod-avec-init -c setup-config
kubectl logs pod-avec-init -c setup-data

# Voir les logs du conteneur principal
kubectl logs pod-avec-init -c main-application

# Vérifier le contenu des volumes
kubectl exec -it pod-avec-init -c main-application -- ls -la /app/config/
kubectl exec -it pod-avec-init -c main-application -- ls -la /app/data/users/
```

---

## Nettoyage

```bash
# Supprimer tous les pods créés
kubectl delete pod mon-premier-pod-multi
kubectl delete pod pod-network-demo
kubectl delete pod app-avec-sidecar
kubectl delete pod pod-avec-init

# Vérifier que tous les pods sont supprimés
kubectl get pods
```

---

### Questions de compréhension :

1. **Partage de volumes** : Pourquoi les conteneurs dans un pod peuvent-ils partager des fichiers ?

2. **Partage de réseau** : Pourquoi les conteneurs peuvent-ils communiquer via `localhost` ?

3. **Init containers** : Dans quel ordre s'exécutent les init containers et les conteneurs principaux ?

4. **Pattern Sidecar** : Donnez 3 exemples d'utilisation du pattern sidecar.

### Bonus :

1. Créez un pod avec 3 conteneurs qui écrivent chacun dans un fichier différent du même volume.

2. Créez un pod où un conteneur fait un serveur web simple et un autre fait des requêtes HTTP toutes les 5 secondes.

3. Modifiez l'exercice sidecar pour que le monitor compte le nombre de lignes dans le log.

