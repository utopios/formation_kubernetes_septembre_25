# Workshop Helm 2

## Objectifs

À la fin, nous saurons :

* Créer un chart Helm from scratch.
* Déclarer et consommer une dépendance Bitnami MySQL.
* Écrire des templates Go (helpers, secrets, deployment, service, PVC).
* Gérer plusieurs environnements (dev, prod).
* Déployer sur GKE et accéder à l’appli par une IP publique de Service LoadBalancer.

## Pré-requis

* gcloud, kubectl, Helm installés et configurés.
* Un projet GCP actif avec droits GKE.
* Connaissances Kubernetes de base.

---

## Étape 0 — Cluster et espace de travail

```bash
kubectl get nodes
```

---

## Étape 1 — Initialisation du chart

```bash
helm create ghost-stack
cd ghost-stack
rm -f templates/* && touch templates/.keep
```

Éditons `Chart.yaml` :

```yaml
apiVersion: v2
name: ghost-stack
description: Ghost CMS on GKE with MySQL dependency (no ingress)
type: application
version: 0.1.0
appVersion: "5.x"
dependencies:
  - name: mysql
    version: 9.x.x
    repository: https://charts.bitnami.com/bitnami
    alias: mysql
```

Mettons à jour la dépendance :

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency update
```

---

## Étape 2 — Fichiers de valeurs

`values.yaml` (base commune) :

```yaml
image:
  repository: bitnami/ghost
  tag: 5-debian-12
  pullPolicy: IfNotPresent

ghost:
  username: admin
  password: "change-me"
  email: admin@example.com
  blogTitle: "Ghost on GKE"
  host: ""                
  urlProtocol: "http"      

service:
  type: LoadBalancer        
  port: 80                  
  targetPort: 2368          

persistence:
  enabled: true
  accessModes: ["ReadWriteOnce"]
  size: 5Gi
  storageClass: ""         

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

mysql:
  primary:
    persistence:
      enabled: true
      size: 8Gi
  auth:
    rootPassword: "root-change-me"
    username: "ghost_user"
    password: "ghost_pass"
    database: "ghost_db"
```

`values-dev.yaml` :

```yaml
ghost:
  blogTitle: "Ghost Dev"

persistence:
  size: 2Gi

mysql:
  primary:
    persistence:
      size: 4Gi
```

`values-prod.yaml` :

```yaml
ghost:
  blogTitle: "Ghost Prod"

persistence:
  size: 20Gi

resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

mysql:
  primary:
    persistence:
      size: 20Gi
  auth:
    rootPassword: "A-changer-en-secret"
    password: "A-changer-en-secret"
```

---

## Étape 3 — Helpers

`templates/_helpers.tpl` :

```gotemplate
{{- define "ghost-stack.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "ghost-stack.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "ghost-stack.labels" -}}
app.kubernetes.io/name: {{ include "ghost-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end }}
```

---

## Étape 4 — Secret et ConfigMap

`templates/secret.yaml` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "ghost-stack.fullname" . }}-ghost
  labels:
    {{- include "ghost-stack.labels" . | nindent 4 }}
type: Opaque
stringData:
  GHOST_USERNAME: {{ .Values.ghost.username | quote }}
  GHOST_PASSWORD: {{ .Values.ghost.password | quote }}
  GHOST_EMAIL: {{ .Values.ghost.email | quote }}
```

`templates/configmap.yaml` (facultatif) :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "ghost-stack.fullname" . }}-config
  labels:
    {{- include "ghost-stack.labels" . | nindent 4 }}
data:
  BLOG_TITLE: {{ .Values.ghost.blogTitle | quote }}
```

---

## Étape 5 — Deployment Ghost

`templates/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "ghost-stack.fullname" . }}-ghost
  labels:
    {{- include "ghost-stack.labels" . | nindent 4 }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "ghost-stack.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
      tier: ghost
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "ghost-stack.name" . }}
        app.kubernetes.io/instance: {{ .Release.Name }}
        tier: ghost
    spec:
      containers:
        - name: ghost
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 2368
          env:
            - name: url
              value: "{{ .Values.ghost.urlProtocol }}://{{ default "localhost" .Values.ghost.host }}"
            - name: database__client
              value: "mysql"
            - name: database__connection__host
              value: "{{ include "ghost-stack.fullname" . }}-mysql"
            - name: database__connection__user
              value: {{ .Values.mysql.auth.username | quote }}
            - name: database__connection__password
              value: {{ .Values.mysql.auth.password | quote }}
            - name: database__connection__database
              value: {{ .Values.mysql.auth.database | quote }}
            - name: GHOST_USERNAME
              valueFrom:
                secretKeyRef:
                  name: {{ include "ghost-stack.fullname" . }}-ghost
                  key: GHOST_USERNAME
            - name: GHOST_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "ghost-stack.fullname" . }}-ghost
                  key: GHOST_PASSWORD
            - name: GHOST_EMAIL
              valueFrom:
                secretKeyRef:
                  name: {{ include "ghost-stack.fullname" . }}-ghost
                  key: GHOST_EMAIL
          volumeMounts:
            - name: ghost-content
              mountPath: /bitnami/ghost
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      volumes:
        - name: ghost-content
          persistentVolumeClaim:
            claimName: {{ include "ghost-stack.fullname" . }}-ghost-pvc
```

---

## Étape 6 — Service et PVC

`templates/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "ghost-stack.fullname" . }}-ghost
  labels:
    {{- include "ghost-stack.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: {{ include "ghost-stack.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    tier: ghost
```

`templates/pvc.yaml` :

```yaml
{{- if .Values.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "ghost-stack.fullname" . }}-ghost-pvc
  labels:
    {{- include "ghost-stack.labels" . | nindent 4 }}
spec:
  accessModes: {{ toYaml .Values.persistence.accessModes | nindent 2 }}
  resources:
    requests:
      storage: {{ .Values.persistence.size }}
  {{- if .Values.persistence.storageClass }}
  storageClassName: {{ .Values.persistence.storageClass }}
  {{- end }}
{{- end }}
```

---

## Étape 7 — Lint et rendu des templates

```bash
helm lint .
helm template ghost ./ -f values.yaml | head -n 80
```

Points d’attention :

* Le Service MySQL du sous-chart sera `{{ .Release.Name }}-ghost-stack-mysql` (nous y référençons `...-mysql` dans les env).
* Le Service Ghost est en LoadBalancer : GKE créera une IP publique.

---

## Étape 8 — Déploiement en dev

```bash
helm upgrade --install ghost-dev . -n ghost --create-namespace -f values.yaml -f values-dev.yaml

kubectl get pods -n ghost
kubectl get svc -n ghost
```

Récupérons l’IP externe :

```bash
kubectl get svc {{YOUR_RELEASE:=ghost-dev}}-ghost-stack-ghost -n ghost -o jsonpath='{.status.loadBalancer.ingress[0].ip}'; echo
```

Ouvrons l’IP dans un navigateur. Identifiants admin depuis le Secret (`ghost.values`).

---

## Étape 9 — Passage en prod

```bash
helm upgrade --install ghost-prod . -n ghost -f values.yaml -f values-prod.yaml
kubectl get svc -n ghost
```

Nous notons l’IP publique du Service `ghost-prod-ghost-stack-ghost` et testons l’accès HTTP.

---

## Étape 10 — Mises à jour, rollback, diagnostic

```bash
# Modifier par exemple ghost.blogTitle puis :
helm upgrade ghost-dev . -n ghost -f values.yaml -f values-dev.yaml

# Historique et retour arrière
helm history ghost-dev -n ghost
helm rollback ghost-dev 1 -n ghost

# Logs et diagnostic
kubectl logs deploy/ghost-dev-ghost-stack-ghost -n ghost
kubectl describe svc/ghost-dev-ghost-stack-ghost -n ghost
kubectl describe pod -l tier=ghost -n ghost
```
