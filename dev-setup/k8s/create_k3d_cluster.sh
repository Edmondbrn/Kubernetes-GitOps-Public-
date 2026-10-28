#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="holograph-cluster"
NFS_DATA_DIR="${NFS_DATA_DIR:-$HOME/.local/share/holograph/nfs-data}"
SEALED_SECRETS_VERSION="${SEALED_SECRETS_VERSION:-v0.39.1}"
SEALED_KEY_BACKUP="${SEALED_KEY_BACKUP:-$HOME/.config/holograph/sealed-secrets-master-key.yaml}"
KEY_LABEL="sealedsecrets.bitnami.com/sealed-secrets-key"

create_cluster() {
  mkdir -p "$NFS_DATA_DIR"
  k3d cluster create "$CLUSTER_NAME" --agents 2 --servers 1 \
    -v "$NFS_DATA_DIR:/shared-data@server:0" \
    -p "80:80@loadbalancer"
}

install_nfs_driver() {
  curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.13.5/deploy/install-driver.sh \
    | bash -s v4.13.5 --
}

install_argocd() {
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply --server-side --force-conflicts -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.6/manifests/install.yaml
}

restore_sealed_key() {
  if [[ -f "$SEALED_KEY_BACKUP" ]]; then
    echo "Restoring sealed-secrets key from $SEALED_KEY_BACKUP"
    kubectl apply -n kube-system -f "$SEALED_KEY_BACKUP"
  else
    echo "WARNING: no key backup at $SEALED_KEY_BACKUP, a new key will be generated" >&2
  fi
}

install_sealed_secrets() {
  kubectl apply -f \
    "https://github.com/bitnami/sealed-secrets/releases/download/${SEALED_SECRETS_VERSION}/controller.yaml"
  kubectl rollout status deployment/sealed-secrets-controller \
    -n kube-system
}

backup_sealed_key() {
  [[ -f "$SEALED_KEY_BACKUP" ]] && return 0
  mkdir -p "$(dirname "$SEALED_KEY_BACKUP")"
  umask 077
  kubectl get secret -n kube-system -l "$KEY_LABEL" -o yaml > "$SEALED_KEY_BACKUP"
  echo "New key saved to $SEALED_KEY_BACKUP: store it in a password manager NOW"
}

main() {
  create_cluster
  install_nfs_driver
  install_argocd
  restore_sealed_key
  install_sealed_secrets
  backup_sealed_key
}

main "$@"