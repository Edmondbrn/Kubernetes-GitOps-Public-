#!/bin/bash -

# Keep the NFS backing directory outside /tmp so it survives host reboots.
NFS_DATA_DIR="${NFS_DATA_DIR:-$HOME/.local/share/holograph/nfs-data}"
mkdir -p "$NFS_DATA_DIR"
k3d cluster create mycluster --agents 2 --servers 1 -v "$NFS_DATA_DIR:/shared-data@server:0"
# install NFS driver
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.13.5/deploy/install-driver.sh | bash -s v4.13.5 --
# install argocd
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.6/manifests/install.yaml

# apply kubeseal if backup key exists

# open port for Ingres
k3d cluster edit mycluster --port-add 80:80@loadbalancer