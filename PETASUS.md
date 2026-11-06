# Petasus build of the KubeVirt CSI driver

This fork builds [kubevirt/csi-driver](https://github.com/kubevirt/csi-driver) for
Petasus, whose KaaS clusters run on KubeVirt VMs created by CAPI and CAPK. It changes
no upstream code. It adds:

- `.github/workflows/`: multi-platform images (linux/amd64, linux/arm64) at
  `quay.io/edgestack/kubevirt-csi-driver`, and the chart `kubevirt-csi` in
  [petasus-ai/edgestack-helm](https://github.com/petasus-ai/edgestack-helm).
- `charts/kubevirt-csi`: the tenant side (node plugin, CSIDriver, StorageClass).
- `charts/kubevirt-csi-hub`: the controller for one tenant cluster, in the
  infrastructure cluster (split mode). It is not published: Petasus Resource Manager
  creates the same objects for every cluster, and the chart serves manual installs and
  as their reference.
- `hack/petasus/verify-charts.sh`: chart checks, run by `verify-charts.yml`.

Upstream publishes no release and, since 2026-10-13, no image (its single `latest` is
amd64 only), so this fork builds one from a commit it pins.

## How it is deployed

| Where | What | Notes |
|---|---|---|
| Infrastructure cluster, the namespace of the tenant's VMs | `kubevirt-csi-hub`: one controller per tenant cluster, a ServiceAccount, Role and RoleBinding per namespace | Reads the tenant through CAPI's `<cluster>-kubeconfig`. Makes DataVolumes labeled `addons.petasus.io/kubevirt-csi-cluster=<cluster>` in one allowed StorageClass, and hotplugs them with VM-level `addvolume` (kept in the VM spec, so a VM restart keeps them). Run with `--enable-vmi-hotplug-fallback=false` on KubeVirt 1.9+, where DeclarativeHotplugVolumes is on and HotplugVolumes is deprecated. |
| Tenant cluster, namespace `kubevirt-csi-driver` | `kubevirt-csi`: node DaemonSet, CSIDriver, StorageClass `kubevirt-csi` | The StorageClass names the infrastructure StorageClass (`infraStorageClassName`) and uses the `scsi` bus. |

The infrastructure StorageClass must be one every infrastructure node can attach
(shared storage). A node-local class such as `hostpath-csi` ties a volume to one node,
and a VM replaced onto another node cannot get it back.

A manual install, for a tenant cluster `c1` whose VMs are in the namespace `project-a`:

```sh
helm install c1-kubevirt-csi charts/kubevirt-csi-hub -n project-a \
  --set clusterName=c1 --set infraStorageClassName=<shared class>
helm install kubevirt-csi charts/kubevirt-csi -n kubevirt-csi-driver --create-namespace \
  --kubeconfig <c1 kubeconfig> --set storageClass.infraStorageClassName=<shared class>
```

A second tenant cluster in the same namespace passes `--set rbac.create=false` to the hub
chart.

## Branches, tags and images

| Ref | Image | Chart |
|---|---|---|
| push to `main` | `:dev` | `0.0.0-dev` on the dev channel, when `charts/kubevirt-csi` changed |
| tag `vX.Y.Z` on `release-X.Y` | `:vX.Y.Z`, and `:latest` for the newest release | `X.Y.Z` on the stable channel |

A tag that is not on its `release-X.Y` branch publishes nothing. A release image or
chart is never replaced.

The repository needs the secrets `QUAY_USER_NAME`, `QUAY_PASSWORD` (push to
`quay.io/edgestack`) and `MY_TOKEN` (push to `petasus-ai/edgestack-helm`). The quay
repository must be public before a release can finish.

## Following upstream

`main` is upstream's `main` with the commits above on top. To move to a newer upstream:

```sh
git fetch upstream
git merge upstream/main     # or rebase the Petasus commits onto it
git push origin main
```

A fix Petasus needs goes upstream as a pull request first. If it is needed before it
merges, it is carried here as its own commit and dropped once upstream has it.
