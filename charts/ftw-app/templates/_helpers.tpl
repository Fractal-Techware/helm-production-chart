{{/*
ftw-app helpers. Names follow Helm conventions; labels follow the Kubernetes
recommended labels (https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/).
*/}}

{{- define "ftw-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ftw-app.fullname" -}}
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

{{- define "ftw-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ftw-app.version" -}}
{{- default .Chart.AppVersion .Values.image.tag | toString | trunc 63 | trimSuffix "-" | trimSuffix "." }}
{{- end }}

{{- define "ftw-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ftw-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Labels shared by resources and pods (no helm.sh/chart: a chart-only bump must not roll pods). */}}
{{- define "ftw-app.podLabels" -}}
{{ include "ftw-app.selectorLabels" . }}
app.kubernetes.io/version: {{ include "ftw-app.version" . | quote }}
app.kubernetes.io/part-of: {{ default .Release.Name .Values.partOf }}
{{- with .Values.component }}
app.kubernetes.io/component: {{ . }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "ftw-app.labels" -}}
helm.sh/chart: {{ include "ftw-app.chart" . }}
{{ include "ftw-app.podLabels" . }}
{{- end }}

{{- define "ftw-app.metadata" -}}
name: {{ include "ftw-app.fullname" . }}
namespace: {{ .Release.Namespace }}
labels:
  {{- include "ftw-app.labels" . | nindent 2 }}
{{- with .Values.commonAnnotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "ftw-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ftw-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* repository[:tag][@digest]; tag defaults to appVersion. */}}
{{- define "ftw-app.image" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag | toString }}
{{- $ref := printf "%s:%s" .Values.image.repository $tag }}
{{- with .Values.image.digest }}
{{- $ref = printf "%s@%s" $ref . }}
{{- end }}
{{- $ref }}
{{- end }}
