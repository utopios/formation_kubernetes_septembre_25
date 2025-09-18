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