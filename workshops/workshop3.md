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

---

## Lab 2 : NodeSelector - Contraintes Simples

### Objectif
Diriger les pods vers des nœuds spécifiques

### Étapes Pratiques

**1. Labelliser vos nœuds**
```bash
# Voir les nœuds existants
kubectl get nodes

# Ajouter des labels personnalisés
kubectl label nodes <NODE-1> environment=production
kubectl label nodes <NODE-1> disktype=ssd
kubectl label nodes <NODE-2> environment=development  
kubectl label nodes <NODE-2> disktype=hdd
```

**2. Pod avec nodeSelector**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: production-pod
spec:
  nodeSelector:
    environment: production
    disktype: ssd
  containers:
  - name: app
    image: nginx:1.21
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
```

**3. Tester avec un label impossible**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: impossible-pod
spec:
  nodeSelector:
    nonexistent: "true"
  containers:
  - name: app
    image: nginx:1.21
```

**4. Observer les résultats**
```bash
kubectl apply -f production-pod.yaml
kubectl apply -f impossible-pod.yaml
kubectl get pods -o wide
kubectl describe pod impossible-pod
```

---

## Lab 3 : Node Affinity - Règles Flexibles

### Objectif
Utiliser des contraintes flexibles et complexes

### Étapes Pratiques

**1. Affinité REQUISE (Hard Constraint)**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: affinity-required
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values: ["ssd", "nvme"]
  containers:
  - name: app
    image: nginx:1.21
```

**2. Affinité PRÉFÉRÉE (Soft Constraint)**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: affinity-preferred
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values: ["ssd"]
      - weight: 20
        preference:
          matchExpressions:
          - key: environment
            operator: In
            values: ["production"]
  containers:
  - name: app
    image: nginx:1.21
```

**3. Combinaison Required + Preferred**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: affinity-combo
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/os
            operator: In
            values: ["linux"]
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 70
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values: ["ssd"]
        - weight: 30
        preference:
            matchExpressions:
            - key: environment
                operator: In
                values: ["production"]
  containers:
  - name: app
    image: nginx:1.21
```

### Exercice Pratique
Créez une règle qui :
- EXIGE Linux
- PRÉFÈRE SSD (poids 70)
- PRÉFÈRE production (poids 30)

Testez sur vos nœuds et observez le placement.


--- 

## Lab 4 : Taints et Tolerations

### Objectif
Réserver des nœuds pour des usages spécifiques

### Étapes Pratiques

**1. Ajouter un taint à un nœud**
```bash
# Choisir un nœud à "dédicacer"
kubectl get nodes
NODE_NAME="<votre-noeud>"

# Ajouter un taint
kubectl taint nodes $NODE_NAME dedicated=gpu:NoSchedule
```

**2. Tenter de déployer un pod normal**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rejected-pod
spec:
  containers:
  - name: app
    image: nginx:1.21
```

**3. Pod avec toleration appropriée**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tolerated-pod
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
  containers:
  - name: gpu-app
    image: nginx:1.21
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
```

**4. Tester les effets de taint**
```bash
# NoExecute : évince les pods existants
kubectl taint nodes $NODE_NAME maintenance=true:NoExecute

# Observer l'éviction
kubectl get pods -o wide --watch
```

**5. Nettoyer les taints**
```bash
kubectl taint nodes $NODE_NAME dedicated=gpu:NoSchedule-
kubectl taint nodes $NODE_NAME maintenance=true:NoExecute-
```