#!/bin/bash -

mkdir -p /tmp/nfs-data
k3d cluster create mycluster --agents 2 --servers 1 -v /tmp/nfs-data:/shared-data@server:0
k3d image import -c mycluster ghcr.io/edmondbrn/mudis_virt_prod:1.0.0 ghcr.io/edmondbrn/mudis_fastapi_prod:1.0.0 ghcr.io/edmondbrn/mudis_postgres_prod:1.0.0 ghcr.io/edmondbrn/mudis_next_prod:1.0.0
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.13.5/deploy/install-driver.sh | bash -s v4.13.5 --
k3d cluster edit mycluster --port-add 80:80@loadbalancer