{{/*
Expand the name of the chart.
*/}}
{{- define "weaura-grafana.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "weaura-grafana.fullname" -}}
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
{{- define "weaura-grafana.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "weaura-grafana.labels" -}}
helm.sh/chart: {{ include "weaura-grafana.chart" . }}
{{ include "weaura-grafana.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
tenant.weaura.io/id: {{ .Values.tenant.id | quote }}
{{- end }}

{{/*
Common annotations (includes tenant.name which may contain spaces)
*/}}
{{- define "weaura-grafana.annotations" -}}
tenant.weaura.io/name: {{ .Values.tenant.name | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "weaura-grafana.selectorLabels" -}}
app.kubernetes.io/name: {{ include "weaura-grafana.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
