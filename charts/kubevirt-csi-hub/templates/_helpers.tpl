{{- define "kubevirt-csi-hub.image" -}}
{{- with .global.imageRegistry }}{{ trimSuffix "/" . }}/{{ end }}{{ .ref }}
{{- end }}

{{- define "kubevirt-csi-hub.clusterName" -}}
{{- required "clusterName is required" .Values.clusterName -}}
{{- end }}

{{/*
The label the controller puts on the DataVolumes it makes, and selects them by: the
tenant clusters of one namespace are told apart by it alone.
*/}}
{{- define "kubevirt-csi-hub.infraClusterLabels" -}}
addons.petasus.io/kubevirt-csi-cluster={{ include "kubevirt-csi-hub.clusterName" . }}
{{- end }}

{{- define "kubevirt-csi-hub.labels" -}}
app.kubernetes.io/name: kubevirt-csi-controller
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
cluster.x-k8s.io/cluster-name: {{ include "kubevirt-csi-hub.clusterName" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}
