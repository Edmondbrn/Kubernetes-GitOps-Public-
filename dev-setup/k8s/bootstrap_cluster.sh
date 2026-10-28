#!/usr/bin/env bash
#
# Bootstrap a complete local k3d environment for Holograph:
#   - create (or reuse) the k3d cluster with the NFS host volume and port 80
#   - install the NFS CSI driver
#   - restore/install Sealed Secrets (the committed SealedSecrets need the
#     original private key)
#   - install Argo CD
#   - create the mudis-dev namespace
#   - apply the AppProject and the root Application (app-of-apps)
#   - wait for the child Applications to be Synced/Healthy
#
# The script is idempotent: rerunning it reuses the cluster and reinstalls
# nothing that is already healthy.
#
# Usage:
#   ./dev-setup/k8s/bootstrap_cluster.sh
#   ./dev-setup/k8s/bootstrap_cluster.sh --no-wait
#   ./dev-setup/k8s/bootstrap_cluster.sh --allow-new-sealed-key
#
# Environment overrides:
#   CLUSTER_NAME, NAMESPACE, ARGOCD_NAMESPACE, HTTP_PORT, NFS_DATA_DIR,
#   NFS_CSI_VERSION, SEALED_SECRETS_VERSION, ARGOCD_VERSION,
#   SEALED_KEY_BACKUP, WAIT_TIMEOUT
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-holograph-cluster}"
NAMESPACE="${NAMESPACE:-mudis-dev}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
HTTP_PORT="${HTTP_PORT:-80}"
NFS_DATA_DIR="${NFS_DATA_DIR:-$HOME/.local/share/holograph/nfs-data}"
NFS_CSI_VERSION="${NFS_CSI_VERSION:-v4.13.5}"
SEALED_SECRETS_VERSION="${SEALED_SECRETS_VERSION:-v0.39.1}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.5.6}"
SEALED_KEY_BACKUP="${SEALED_KEY_BACKUP:-$HOME/.config/holograph/sealed-secrets-master-key.yaml}"
SEALED_KEY_LABEL="sealedsecrets.bitnami.com/sealed-secrets-key"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-900}"

ALLOW_NEW_SEALED_KEY=0
ALLOW_LOCAL_CHANGES=0
WAIT_APPS=1

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Bootstrap the k3d cluster, Argo CD, the mudis-dev namespace and the app-of-apps.

Options:
  --allow-new-sealed-key   Generate a new Sealed Secrets key when no backup is
                           available. The committed SealedSecrets will NOT be
                           readable: reseal them with kubeseal afterwards.
  --allow-local-changes    Allow running with uncommitted manifest/ or argocd/
                           changes. Argo CD syncs the remote branch, so those
                           changes will not be deployed.
  --no-wait                Do not wait for Argo CD Applications to be healthy.
  -h, --help               Show this help.

Environment overrides:
  CLUSTER_NAME=${CLUSTER_NAME}
  NAMESPACE=${NAMESPACE}
  ARGOCD_NAMESPACE=${ARGOCD_NAMESPACE}
  HTTP_PORT=${HTTP_PORT}
  NFS_DATA_DIR=${NFS_DATA_DIR}
  SEALED_KEY_BACKUP=${SEALED_KEY_BACKUP}
  WAIT_TIMEOUT=${WAIT_TIMEOUT}s
EOF
}

while (( $# )); do
  case "$1" in
    --allow-new-sealed-key) ALLOW_NEW_SEALED_KEY=1 ;;
    --allow-local-changes)  ALLOW_LOCAL_CHANGES=1 ;;
    --no-wait)              WAIT_APPS=0 ;;
    -h|--help)              usage; exit 0 ;;
    *)                      die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

require_tools() {
  local tool
  for tool in k3d kubectl curl git; do
    command -v "$tool" >/dev/null 2>&1 || die "'${tool}' is required but was not found in PATH"
  done
}

cluster_exists() {
  k3d cluster list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$CLUSTER_NAME"
}

use_cluster_context() {
  k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context >/dev/null 2>&1 || true
  kubectl config use-context "k3d-${CLUSTER_NAME}" >/dev/null 2>&1 \
    || die "Cannot switch kubectl to context k3d-${CLUSTER_NAME}"
}

nfs_manifest_selector() {
  awk '
    /^[[:space:]]*nodeSelector:/ { in_selector = 1; next }
    in_selector && /kubernetes\.io\/hostname:/ {
      sub(/^[^:]*:[[:space:]]*/, "")
      print
      exit
    }
  ' "${REPO_ROOT}/manifest/base/platform/deployments/nfs-server-deployment.yaml"
}

ensure_cluster() {
  log "k3d cluster '${CLUSTER_NAME}'"

  if cluster_exists; then
    log "Cluster already exists, reusing it"
  else
    mkdir -p "$NFS_DATA_DIR"
    k3d cluster create "$CLUSTER_NAME" \
      --agents 2 \
      --servers 1 \
      -v "${NFS_DATA_DIR}:/shared-data@server:0" \
      -p "${HTTP_PORT}:80@loadbalancer"
  fi

  use_cluster_context
  kubectl wait --for=condition=Ready nodes --all --timeout=180s

  local server_node="k3d-${CLUSTER_NAME}-server-0"
  kubectl get node "$server_node" >/dev/null 2>&1 \
    || die "Expected node '${server_node}' does not exist"

  # The NFS server is pinned to the k3d server node. Catch the drift early:
  # a wrong selector leaves nfs-server Pending and every RWX PVC unbound.
  local selector
  selector="$(nfs_manifest_selector)"
  [[ -n "$selector" ]] || die "Cannot read the NFS nodeSelector from the manifest"
  [[ "$selector" == "$server_node" ]] || die \
    "NFS nodeSelector mismatch: manifest has '${selector}', cluster node is '${server_node}'.
     Fix manifest/base/platform/deployments/nfs-server-deployment.yaml before continuing."

  if command -v docker >/dev/null 2>&1; then
    if ! docker port "k3d-${CLUSTER_NAME}-serverlb" 2>/dev/null | grep -q ":${HTTP_PORT}$"; then
      warn "Port ${HTTP_PORT} does not appear to be published by k3d. Ingress on http://app.localhost may not work."
    fi
  fi
}

ensure_namespace() {
  log "Namespace '${NAMESPACE}'"
  kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 \
    || kubectl create namespace "$NAMESPACE"
}

install_nfs_csi() {
  log "NFS CSI driver ${NFS_CSI_VERSION}"
  if ! kubectl -n kube-system get deployment csi-nfs-controller >/dev/null 2>&1; then
    curl -skSL "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/${NFS_CSI_VERSION}/deploy/install-driver.sh" \
      | bash -s "$NFS_CSI_VERSION" --
  else
    log "NFS CSI driver already installed"
  fi
  kubectl -n kube-system rollout status deployment/csi-nfs-controller --timeout=180s
  kubectl -n kube-system rollout status daemonset/csi-nfs-node --timeout=180s
}

install_sealed_secrets() {
  log "Sealed Secrets ${SEALED_SECRETS_VERSION}"

  if [[ -f "$SEALED_KEY_BACKUP" ]]; then
    log "Restoring the Sealed Secrets private key from ${SEALED_KEY_BACKUP}"
    kubectl apply -f "$SEALED_KEY_BACKUP"
  elif (( ALLOW_NEW_SEALED_KEY )); then
    warn "No key backup at ${SEALED_KEY_BACKUP}: a new key will be generated."
    warn "The SealedSecrets committed in this repository will NOT decrypt."
  else
    die "No Sealed Secrets key backup at ${SEALED_KEY_BACKUP}.
     The SealedSecrets in this repository cannot be decrypted without it.
     Restore the key, or rerun with --allow-new-sealed-key and reseal every secret."
  fi

  if ! kubectl -n kube-system get deployment sealed-secrets-controller >/dev/null 2>&1; then
    kubectl apply -f "https://github.com/bitnami/sealed-secrets/releases/download/${SEALED_SECRETS_VERSION}/controller.yaml"
  fi
  kubectl -n kube-system rollout status deployment/sealed-secrets-controller --timeout=180s

  # If the controller was already running with another key, restart it so the
  # restored key is loaded.
  kubectl -n kube-system rollout restart deployment/sealed-secrets-controller >/dev/null
  kubectl -n kube-system rollout status deployment/sealed-secrets-controller --timeout=180s

  if [[ ! -f "$SEALED_KEY_BACKUP" ]]; then
    local i
    for i in $(seq 1 30); do
      kubectl get secret -n kube-system -l "$SEALED_KEY_LABEL" -o name 2>/dev/null | grep -q . && break
      sleep 2
    done
    kubectl get secret -n kube-system -l "$SEALED_KEY_LABEL" -o name 2>/dev/null | grep -q . \
      || die "Sealed Secrets did not create its private key"

    log "Saving the new private key to ${SEALED_KEY_BACKUP}"
    mkdir -p "$(dirname "$SEALED_KEY_BACKUP")"
    ( umask 077; kubectl get secret -n kube-system -l "$SEALED_KEY_LABEL" -o yaml > "$SEALED_KEY_BACKUP" )
    warn "Back up ${SEALED_KEY_BACKUP} outside the cluster: without it the committed SealedSecrets are lost."
  fi
}

install_argocd() {
  log "Argo CD ${ARGOCD_VERSION}"
  kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  if ! kubectl -n "$ARGOCD_NAMESPACE" get deployment argocd-server >/dev/null 2>&1; then
    # Server-side apply is required: the ApplicationSet CRD is too large for
    # the client-side last-applied-configuration annotation.
    kubectl apply --server-side --force-conflicts -n "$ARGOCD_NAMESPACE" \
      -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
  else
    log "Argo CD already installed"
  fi

  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-server --timeout=300s
  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-repo-server --timeout=300s
  kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=120s
}

check_local_changes() {
  local repo_url branch
  repo_url="$(awk '/repoURL:/{print $2; exit}' "${REPO_ROOT}/argocd/root-app.yaml")"
  branch="$(awk '/targetRevision:/{print $2; exit}' "${REPO_ROOT}/argocd/root-app.yaml")"

  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain -- manifest argocd 2>/dev/null)" ]]; then
    if (( ALLOW_LOCAL_CHANGES )); then
      warn "manifest/ or argocd/ has uncommitted changes and --allow-local-changes is set."
      warn "Argo CD syncs ${repo_url} (${branch}), not this working tree: those changes will not be deployed."
    else
      die "manifest/ or argocd/ has uncommitted changes.
     Argo CD syncs ${repo_url} (${branch}), not this working tree.
     Commit and push them first, or rerun with --allow-local-changes."
    fi
  fi
}

deploy_app_of_apps() {
  log "AppProject and root Application"
  kubectl apply -f "${REPO_ROOT}/argocd/projects/mudis.yaml"
  kubectl apply -f "${REPO_ROOT}/argocd/root-app.yaml"
}

wait_for_application() {
  local app="$1"
  local deadline=$((SECONDS + WAIT_TIMEOUT))
  local state=""

  while (( SECONDS < deadline )); do
    state="$(kubectl -n "$ARGOCD_NAMESPACE" get application "$app" \
      -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)"
    if [[ "$state" == "Synced/Healthy" ]]; then
      log "Application ${app}: ${state}"
      return 0
    fi
    sleep 5
  done

  warn "Application ${app} is not Synced/Healthy after ${WAIT_TIMEOUT}s (last state: ${state:-not found})"
  return 1
}

wait_for_applications() {
  log "Waiting for Argo CD Applications (timeout ${WAIT_TIMEOUT}s)"
  local failed=0
  wait_for_application root || failed=1
  wait_for_application platform || failed=1
  wait_for_application mudis || failed=1
  return "$failed"
}

show_status() {
  log "Argo CD Applications"
  kubectl -n "$ARGOCD_NAMESPACE" get applications || true

  log "Workloads and storage in '${NAMESPACE}'"
  kubectl -n "$NAMESPACE" get pods,pvc || true

  local password=""
  password="$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || true)"

  cat <<EOF

Cluster '${CLUSTER_NAME}' is bootstrapped.

  Namespace : ${NAMESPACE}
  Argo CD   : kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8080:443
              https://localhost:8080  (admin / ${password:-see argocd-initial-admin-secret})
  App       : http://app.localhost

Next steps:
  kubectl -n ${NAMESPACE} get pods -w
  kubectl -n ${NAMESPACE} get pvc
EOF
}

main() {
  require_tools
  log "Repository: ${REPO_ROOT}"
  check_local_changes
  ensure_cluster
  ensure_namespace
  install_nfs_csi
  install_sealed_secrets
  install_argocd
  deploy_app_of_apps

  if (( WAIT_APPS )); then
    wait_for_applications || {
      show_status
      die "Some Argo CD Applications are not healthy yet. Inspect them with: kubectl -n ${ARGOCD_NAMESPACE} get applications"
    }
  fi

  show_status
}

main "$@"
