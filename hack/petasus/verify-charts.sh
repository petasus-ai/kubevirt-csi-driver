#!/usr/bin/env bash
# Lint and render the Petasus charts, and check what they must and must not render.
# Needs helm. Run from the repository root.
set -euo pipefail

tenant=charts/kubevirt-csi
hub=charts/kubevirt-csi-hub
fail() { echo "FAIL: $*" >&2; exit 1; }

helm lint "$tenant" --set storageClass.infraStorageClassName=nfs-csi
helm lint "$hub" --set clusterName=c1 --set infraStorageClassName=nfs-csi

# Tenant: the StorageClass names the infra class, is not the default unless asked, and
# images take the registry prefix.
out=$(helm template t "$tenant" -n kubevirt-csi-driver \
  --set storageClass.infraStorageClassName=nfs-csi \
  --set global.imageRegistry=harbor.example:32443/library/)
grep -q 'infraStorageClassName: "nfs-csi"' <<<"$out" || fail "tenant: infraStorageClassName"
grep -q 'bus: "scsi"' <<<"$out" || fail "tenant: bus"
grep -q 'is-default-class: "false"' <<<"$out" || fail "tenant: default class"
grep -q 'volumeBindingMode: Immediate' <<<"$out" || fail "tenant: binding mode"
grep -q 'image: harbor.example:32443/library/quay.io/edgestack/kubevirt-csi-driver:dev' <<<"$out" || fail "tenant: driver image"
grep -q 'image: harbor.example:32443/library/registry.k8s.io/sig-storage/csi-node-driver-registrar:' <<<"$out" || fail "tenant: registrar image"

out=$(helm template t "$tenant" --set storageClass.infraStorageClassName=x --set storageClass.isDefaultClass=true)
grep -q 'is-default-class: "true"' <<<"$out" || fail "tenant: isDefaultClass=true"

out=$(helm template t "$tenant" --set storageClass.create=false)
grep -q 'kind: StorageClass' <<<"$out" && fail "tenant: StorageClass rendered with create=false"

helm template t "$tenant" >/dev/null 2>&1 && fail "tenant: renders without infraStorageClassName"
helm template t "$tenant" --set storageClass.infraStorageClassName=x --set storageClass.fsType=btrfs >/dev/null 2>&1 &&
  fail "tenant: renders with fsType btrfs"

# Hub: per-cluster names and labels, the allow list holds the infra class alone, the
# fallback is off, and the kubeconfig is CAPI's.
out=$(helm template h "$hub" -n project-a --set clusterName=c1 --set infraStorageClassName=nfs-csi)
grep -q 'name: c1-kubevirt-csi-controller' <<<"$out" || fail "hub: deployment name"
grep -q -- '--infra-cluster-namespace=project-a' <<<"$out" || fail "hub: infra namespace"
grep -q -- '--infra-cluster-labels=addons.petasus.io/kubevirt-csi-cluster=c1' <<<"$out" || fail "hub: labels"
grep -q -- '--enable-vmi-hotplug-fallback=false' <<<"$out" || fail "hub: fallback"
grep -q 'allowAll: false' <<<"$out" || fail "hub: allowAll"
grep -q 'allowDefault: false' <<<"$out" || fail "hub: allowDefault"
grep -q -- '- "nfs-csi"' <<<"$out" || fail "hub: allowList"
grep -q 'secretName: c1-kubeconfig' <<<"$out" || fail "hub: kubeconfig secret"
grep -q 'name: project-a-kubevirt-csi' <<<"$out" || fail "hub: per-namespace cluster role"

out=$(helm template h "$hub" --set clusterName=c2 --set infraStorageClassName=x --set rbac.create=false)
grep -q 'kind: Role' <<<"$out" && fail "hub: RBAC rendered with rbac.create=false"

helm template h "$hub" --set infraStorageClassName=x >/dev/null 2>&1 && fail "hub: renders without clusterName"
helm template h "$hub" --set clusterName=c1 >/dev/null 2>&1 && fail "hub: renders without infraStorageClassName"

echo "charts OK"
