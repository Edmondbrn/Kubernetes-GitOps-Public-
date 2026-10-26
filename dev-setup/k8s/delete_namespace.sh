#!/bin/bash -

# force deletion of the namespace, NFS server is deleted first and PVCs are then stuck in dead lock mod
set -u

NS="${1:-mudis-dev}"

echo "Force-deleting pods in namespace ${NS}..."
kubectl -n "${NS}" delete pod --all --grace-period=0 --force 2>/dev/null || true

echo "Deleting namespace ${NS}..."
kubectl delete namespace "${NS}" --wait=false 2>/dev/null || true

echo "Waiting for namespace to disappear..."
for _ in $(seq 1 60); do
  if ! kubectl get namespace "${NS}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Cleaning released nfs-csi PVs (dangling CSI finalizers)..."
for pv in $(kubectl get pv -o jsonpath='{range .items[?(@.status.phase=="Released")]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
  storage_class=$(kubectl get pv "${pv}" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || true)
  if [ "${storage_class}" = "nfs-csi" ]; then
    echo "  removing finalizers from ${pv}"
    kubectl patch pv "${pv}" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
    kubectl delete pv "${pv}" --wait=false >/dev/null 2>&1 || true
  fi
done

if kubectl get namespace "${NS}" >/dev/null 2>&1; then
  echo "Namespace ${NS} still exists. Check: kubectl get namespace ${NS} -o yaml"
else
  echo "Namespace ${NS} deleted."
fi
