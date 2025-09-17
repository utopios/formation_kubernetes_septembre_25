# Workshop - Sécurité Kubernetes

## Objectif
Apprendre et mettre en pratique les mécanismes de sécurité essentiels dans Kubernetes.

---

## Étape 1 : Préparer le cluster et les namespaces

```bash
# Vérifier le cluster
kubectl get nodes

# Créer les namespaces pour l'exercice
kubectl create namespace production
kubectl create namespace development
kubectl create namespace monitoring
```

---

## Étape 2 : RBAC - ServiceAccounts et Rôles

### 2.1 Créer des ServiceAccounts
```yaml
# service-accounts.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: production
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-writer
  namespace: production
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-user
  namespace: development
```

### 2.2 Créer des Rôles
```yaml
# roles.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: deployment-manager
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

### 2.3 Lier les rôles aux utilisateurs
```yaml
# role-bindings.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-writer-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-writer
  namespace: production
roleRef:
  kind: Role
  name: deployment-manager
  apiGroup: rbac.authorization.k8s.io
```

**Déployer :**
```bash
kubectl apply -f service-accounts.yaml
kubectl apply -f roles.yaml
kubectl apply -f role-bindings.yaml
```

---

## Étape 3 : Tester les permissions RBAC

### 3.1 Créer un pod de test
```yaml
# test-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
```

### 3.2 Tester les permissions
```bash
kubectl apply -f test-app.yaml

# Tester avec le ServiceAccount app-reader (lecture seule)
kubectl auth can-i get pods --namespace production --as=system:serviceaccount:production:app-reader
kubectl auth can-i create deployments --namespace production --as=system:serviceaccount:production:app-reader

# Tester avec le ServiceAccount app-writer (lecture + écriture)
kubectl auth can-i get pods --namespace production --as=system:serviceaccount:production:app-writer
kubectl auth can-i create deployments --namespace production --as=system:serviceaccount:production:app-writer

# Voir les permissions d'un ServiceAccount
kubectl describe rolebinding app-reader-binding -n production
```

---

## Étape 4 : Security Contexts (contextes de sécurité)

### 4.1 Pod non sécurisé (à éviter)
```yaml
# insecure-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: development
spec:
  containers:
  - name: app
    image: nginx:alpine
    # Pas de security context = privilèges par défaut
```

### 4.2 Pod sécurisé
```yaml
# secure-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: production
spec:
  serviceAccountName: app-reader
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
    volumeMounts:
    - name: tmp-volume
      mountPath: /tmp
    - name: cache-volume
      mountPath: /var/cache/nginx
  volumes:
  - name: tmp-volume
    emptyDir: {}
  - name: cache-volume
    emptyDir: {}
```

**Déployer et comparer :**
```bash
kubectl apply -f insecure-pod.yaml
kubectl apply -f secure-pod.yaml

# Comparer les processus et permissions
kubectl exec -it insecure-pod -- ps aux
kubectl exec -it secure-pod -- ps aux

# Tenter des actions privilégiées
kubectl exec -it insecure-pod -- whoami
kubectl exec -it secure-pod -- whoami
```

---

## Étape 5 : Gestion sécurisée des Secrets

### 5.1 Créer des secrets
```yaml
# app-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: production
type: Opaque
data:
  username: YWRtaW4=  # admin
  password: UGFzc3dvcmQxMjM=  # Password123
---
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
  namespace: production
type: Opaque
data:
  api-key: YWJjZGVmZ2hpams=  # abcdefghijk
  secret-key: bXlzZWNyZXRrZXk=  # mysecretkey
```

### 5.2 Pod utilisant les secrets de manière sécurisée
```yaml
# app-with-secrets.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      serviceAccountName: app-reader
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
      containers:
      - name: app
        image: busybox
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'App running with secrets...'; sleep 30; done"]
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: api-key
        volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
      volumes:
      - name: secret-volume
        secret:
          secretName: db-credentials
          defaultMode: 0400  # Lecture seule pour le propriétaire
```

**Déployer et vérifier :**
```bash
kubectl apply -f app-secrets.yaml
kubectl apply -f app-with-secrets.yaml

# Vérifier que les secrets sont accessibles mais sécurisés
kubectl exec -it $(kubectl get pod -l app=secure-app -n production -o name) -n production -- env | grep -E "(DB_|API_)"
kubectl exec -it $(kubectl get pod -l app=secure-app -n production -o name) -n production -- ls -la /etc/secrets/
```

---

## Étape 6 : Network Policies (isolation réseau)

### 6.1 Déployer une application frontend et backend
```yaml
# network-test-apps.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: production
spec:
  selector:
    app: frontend
  ports:
  - port: 80
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      tier: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: app
        image: httpd:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: production
spec:
  selector:
    app: backend
  ports:
  - port: 80
  type: ClusterIP
```

### 6.2 Network Policy restrictive
```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to: []  # Permet le trafic DNS
    ports:
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-netpol
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 80
  - to: []  # DNS
    ports:
    - protocol: UDP
      port: 53
```

**Déployer et tester :**
```bash
kubectl apply -f network-test-apps.yaml
kubectl apply -f network-policy.yaml

# Tester la connectivité avant et après les Network Policies
kubectl exec -it $(kubectl get pod -l app=frontend -n production -o name | head -1) -n production -- wget -qO- backend-service

# Tester depuis un autre pod (devrait échouer)
kubectl run test-pod --image=busybox --rm -it --restart=Never -n production -- wget -qO- backend-service
```

---

## Étape 7 : Pod Security Standards

### 7.1 Configurer les Pod Security Standards
```yaml
# pod-security-policy.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-ns
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 7.2 Pod conforme aux standards restrictifs
```yaml
# compliant-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: restricted-ns
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

### 7.3 Pod non conforme (sera rejeté)
```yaml
# non-compliant-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: non-compliant-pod
  namespace: restricted-ns
spec:
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      privileged: true  # Interdit par les standards restrictifs
```

**Tester :**
```bash
kubectl apply -f pod-security-policy.yaml
kubectl apply -f compliant-pod.yaml
kubectl apply -f non-compliant-pod.yaml  # Devrait échouer
```

---

## Étape 8 : Scan de sécurité et monitoring

### 8.1 Vérifier les permissions actuelles
```bash
# Audit des permissions RBAC
kubectl get rolebindings,clusterrolebindings --all-namespaces -o wide

# Voir les ServiceAccounts et leurs permissions
kubectl get serviceaccounts --all-namespaces
kubectl auth can-i --list --as=system:serviceaccount:production:app-reader -n production
```

### 8.2 Analyse des Security Contexts
```bash
# Voir les Security Contexts des pods
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'

# Identifier les pods privilégiés
kubectl get pods --all-namespaces -o json | grep -A 5 -B 5 '"privileged": true'
```

### 8.3 Vérification des secrets
```bash
# Lister tous les secrets
kubectl get secrets --all-namespaces

# Vérifier les permissions sur les secrets
kubectl auth can-i get secrets --all-namespaces
kubectl auth can-i create secrets --all-namespaces
```

---

## Étape 9 : Bonnes pratiques de sécurité

### 9.1 Deployment sécurisé complet
```yaml
# secure-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-web-app
  namespace: production
  labels:
    app: secure-web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-web-app
  template:
    metadata:
      labels:
        app: secure-web-app
    spec:
      serviceAccountName: app-reader
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: web
        image: nginx:1.21-alpine
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /var/cache/nginx
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}
```

**Déployer :**
```bash
kubectl apply -f secure-deployment.yaml
```

---

## Étape 10 : Audit et surveillance

### 10.1 Commandes d'audit
```bash
# Vérifier les événements de sécurité
kubectl get events --all-namespaces --field-selector type=Warning

# Analyser les logs des pods pour les erreurs de sécurité
kubectl logs -l app=secure-web-app -n production

# Vérifier les ressources et limites
kubectl describe pod -l app=secure-web-app -n production
```

### 10.2 Tests de pénétration basiques
```bash
# Tenter d'accéder aux secrets depuis un pod
kubectl exec -it $(kubectl get pod -l app=secure-web-app -n production -o name | head -1) -n production -- env

# Tenter des escalades de privilèges
kubectl exec -it $(kubectl get pod -l app=secure-web-app -n production -o name | head -1) -n production -- whoami
kubectl exec -it $(kubectl get pod -l app=secure-web-app -n production -o name | head -1) -n production -- ls -la /
```


---

## Nettoyage

```bash
# Supprimer les ressources créées
kubectl delete namespace production development monitoring restricted-ns --wait=true

# Vérifier que tout est supprimé
kubectl get namespaces
kubectl get clusterrolebindings | grep -E "(app-|dev-|monitoring-)"
```
