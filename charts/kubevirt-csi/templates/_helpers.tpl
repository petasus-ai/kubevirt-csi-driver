{{/*
An image reference with the registry prefix of global.imageRegistry, if any.
Call with (dict "ref" <image> "global" .Values.global).
*/}}
{{- define "kubevirt-csi.image" -}}
{{- with .global.imageRegistry }}{{ trimSuffix "/" . }}/{{ end }}{{ .ref }}
{{- end }}

{{- define "kubevirt-csi.driverImage" -}}
{{- $ref := printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- include "kubevirt-csi.image" (dict "ref" $ref "global" .Values.global) -}}
{{- end }}

{{- define "kubevirt-csi.labels" -}}
app.kubernetes.io/name: kubevirt-csi
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ default .Chart.AppVersion .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}
