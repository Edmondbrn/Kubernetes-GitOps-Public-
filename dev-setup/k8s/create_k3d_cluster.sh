#!/bin/bash -

mkdir -p /tmp/nfs-data
k3d cluster create mycluster --agents 2 --servers 1 -v /tmp/nfs-data:/shared-data@server:0
k3d image import -c mycluster ghcr.io/<github-user>/holograph-virtuoso:1.0.0 ghcr.io/<github-user>/holograph-backend:1.0.0 ghcr.io/<github-user>/holograph-postgres:1.0.0 ghcr.io/<github-user>/holograph-frontend:1.0.0
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.13.5/deploy/install-driver.sh | bash -s v4.13.5 --
k3d cluster edit mycluster --port-add 80:80@loadbalancer