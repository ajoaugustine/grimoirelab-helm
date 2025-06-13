{{/*
Expand the name of the chart.
*/}}
{{- define "grimoirelab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "grimoirelab.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "grimoirelab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "grimoirelab.labels" -}}
helm.sh/chart: {{ include "grimoirelab.chart" . }}
{{ include "grimoirelab.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "grimoirelab.selectorLabels" -}}
app.kubernetes.io/name: {{ include "grimoirelab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "grimoirelab.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "grimoirelab.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Component labels
*/}}
{{- define "grimoirelab.componentLabels" -}}
{{ include "grimoirelab.labels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Database connection string for MariaDB
*/}}
{{- define "grimoirelab.mariadb.connectionString" -}}
{{- printf "mysql://%s:%s@%s:%d/%s" .user .password (include "grimoirelab.mariadb.host" .) (.Values.mariadb.service.port | int) .Values.mariadb.auth.database }}
{{- end }}

{{/*
MariaDB host
*/}}
{{- define "grimoirelab.mariadb.host" -}}
{{- printf "%s-mariadb" (include "grimoirelab.fullname" .) }}
{{- end }}

{{/*
Elasticsearch host
*/}}
{{- define "grimoirelab.elasticsearch.host" -}}
{{- printf "%s-elasticsearch" (include "grimoirelab.fullname" .) }}
{{- end }}

{{/*
Redis host
*/}}
{{- define "grimoirelab.redis.host" -}}
{{- printf "%s-redis" (include "grimoirelab.fullname" .) }}
{{- end }}

{{/*
Image name helper
*/}}
{{- define "grimoirelab.image" -}}
{{- if .global.imageRegistry }}
{{- printf "%s/%s:%s" .global.imageRegistry .repository .tag }}
{{- else }}
{{- printf "%s:%s" .repository .tag }}
{{- end }}
{{- end }}

{{/*
Wait for service helper
*/}}
{{- define "grimoirelab.waitForService" -}}
- name: wait-for-{{ .service }}
  image: busybox:1.35
  command: ['sh', '-c']
  args:
    - |
      until nc -z {{ .host }} {{ .port }}; do
        echo "Waiting for {{ .service }} to be ready..."
        sleep 5
      done
      echo "{{ .service }} is ready"
{{- end }}
