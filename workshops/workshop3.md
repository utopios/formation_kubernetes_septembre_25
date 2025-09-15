# Workshop 3
---


## Lab 1 : Observation du Scheduler par Défaut

### Objectif
Comprendre le comportement naturel du scheduler

### Étapes Pratiques

**1. Créer un Deployment simple**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: observer-scheduler
spec:
  replicas: 6
  selector:
    matchLabels:
      app: observer
  template:
    metadata:
      labels:
        app: observer
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
```

**2. Appliquer et observer**
```bash
kubectl apply -f deployment.yaml
kubectl get pods -o wide
```

**3. Analyser la répartition**
```bash
# Compter les pods par nœud
kubectl get pods -l app=observer -o wide | awk '{print $7}' | sort | uniq -c

# Voir les événements de scheduling
kubectl get events --sort-by=.metadata.creationTimestamp | grep Scheduled
```

### Questions de Réflexion
- Comment le scheduler répartit-il les 6 pods ?
- Y a-t-il une logique d'équilibrage ?
- Que se passe-t-il si vous redéployez ?