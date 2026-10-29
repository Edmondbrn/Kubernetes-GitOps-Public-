# Holograph-web — Kubernetes / GitOps deployment

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Argo CD](https://img.shields.io/badge/Argo%20CD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Kustomize](https://img.shields.io/badge/Kustomize-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Next.js](https://img.shields.io/badge/Next.js-000000?style=for-the-badge&logo=next.js&logoColor=white)
![RDF](https://img.shields.io/badge/RDF-E10098?style=for-the-badge&logo=semanticweb&logoColor=white)

**Deployment-only repository.** The application source code (FastAPI, Next.js,
Virtuoso loaders, documentation site) is private and not open source yet. This
repository publishes the container/deployment assets and the Kubernetes/GitOps
configuration so the architecture can be reviewed.

The application source tree is kept as empty placeholders (`fastapi_backend/`,
`next_frontend/`, `doc-app/`) so the layout stays readable.

## Repository layout

```
argocd/            AppProject, root Application and child Applications
manifest/
  base/platform/   Namespace-agnostic platform layer: config, secrets,
                   NetworkPolicies, storage, Postgres / Virtuoso / Redis
  base/app/        Application layer: FastAPI, Celery, Next.js, Jobs and CronJobs
  overlays/k3d/    k3d overlay: namespace, NFS server/StorageClass, platform/app
                   and monitoring entry points
postgres/          Postgres image build context (backup scripts, crontab)
virtuoso/          Virtuoso image build context
fastapi_backend/   Dockerfile only (source is private)
next_frontend/     Dockerfile only (source is private)
dev-setup/         helper scripts (k3d cluster, image rebuild, env templates)
docker-compose*.yml / docker.sh / start.sh   compose reference workflow
```

## Container images (private)

Images are published as **private** GitHub Container Registry packages:

| Image                                    | Component         |
| ---------------------------------------- | ----------------- |
| `ghcr.io/edmondbrn/holograph-web/mudis_fastapi_prod`   | FastAPI + Celery  |
| `ghcr.io/edmondbrn/holograph-web/mudis_next_prod`      | Next.js           |
| `ghcr.io/edmondbrn/holograph-web/mudis_postgres_prod`  | PostgreSQL 18     |
| `ghcr.io/edmondbrn/holograph-web/mudis_virt_prod`      | OpenLink Virtuoso |

All images are tagged `1.0.0` in the Kustomize base. Because the tag is mutable
during this validation phase, the application containers use
`imagePullPolicy: Always` so a re-pushed `1.0.0` is actually pulled.

Request access from the repository owner, then create the pull secret locally
(it is intentionally **not** committed):

```bash
kubectl create namespace mudis-dev
kubectl -n mudis-dev create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=edmondbrn \
  --docker-password=<PAT-with-read:packages>
```

The workloads reference this secret through `imagePullSecrets: [{name: ghcr-pull}]`,
so create it in the `mudis-dev` namespace before the pods start.

## Deploy on k3d

The bootstrap script creates (or reuses) the `holograph-cluster` k3d cluster,
installs the NFS CSI driver, restores the Sealed Secrets key, installs Argo CD,
creates the `mudis-dev` namespace and applies the app-of-apps:

```bash
./dev-setup/k8s/bootstrap_cluster.sh
```

It is idempotent and accepts:

```bash
./dev-setup/k8s/bootstrap_cluster.sh --no-wait
./dev-setup/k8s/bootstrap_cluster.sh --allow-new-sealed-key
./dev-setup/k8s/bootstrap_cluster.sh --help
```

Prerequisites:

- `k3d`, `kubectl`, `curl`, `git` and Docker must be installed;
- the four private images must be pullable (see above);
- the Sealed Secrets private key must exist offline at
  `${SEALED_KEY_BACKUP:-$HOME/.config/holograph/sealed-secrets-master-key.yaml}`.
  The committed `SealedSecret` resources cannot be decrypted without it;
- the NFS export uses `$HOME/.local/share/holograph/nfs-data` (override with
  `NFS_DATA_DIR`). It must survive cluster recreation.

To deploy without Argo CD, apply the overlay directly:

```bash
kubectl apply -k manifest/overlays/k3d
kubectl -n mudis-dev get pods -w
```

### k3d / NFS troubleshooting

The local NFS server backs the `RWX` volumes (`app-logs`, `celery-data`,
`user-results`). Its data directory must live outside `/tmp`; the helper script
uses `$HOME/.local/share/holograph/nfs-data` (override with `NFS_DATA_DIR`).

If that directory is lost while the PVs still exist, mounts fail with
`No such file or directory`, and pods can stay in `Unknown`/`Terminating`:

```bash
# Recreate the missing export subdirectories (names = PV names)
kubectl -n mudis-dev exec deploy/nfs-server -- \
  sh -c 'ls /exports; mkdir -p /exports/<pv-name>'

# Force-delete pods the kubelet can no longer finalize
kubectl -n mudis-dev delete pod <pod> --grace-period=0 --force
```

If a whole namespace deletion hangs, run the cleanup helper:

```bash
./dev-setup/k8s/delete_namespace.sh mudis-dev
```

It force-deletes the pods (which unblocks the namespace controller) and removes
the dangling finalizers from the released `nfs-csi` PVs.

The `nfs-csi` StorageClass uses `soft` mounts in this dev setup so a missing
NFS server cannot block pod termination forever. Use `hard` mounts for
production storage.

## GitOps (Argo CD)

Argo CD v3.5.6 watches this repository and uses an **app-of-apps** layout:

```
argocd/root-app.yaml               root Application -> argocd/apps/
argocd/projects/mudis.yaml         AppProject for the application (mudis-dev)
argocd/projects/monitoring.yaml    AppProject for the observability stack
argocd/apps/platform.yaml          Application, sync-wave -1
argocd/apps/monitoring.yaml        Application (Helm), sync-wave -3
argocd/apps/monitoring-addons.yaml Application, sync-wave -2
argocd/apps/mudis.yaml             Application, sync-wave 0
```

The `platform` Application owns the namespace, storage, config, SealedSecrets,
Postgres, Redis, Virtuoso and the NFS server. The `mudis` Application owns the
FastAPI, Celery and Next.js workloads plus the Postgres/Redis exporters. Both
target the `mudis-dev` namespace.

The `monitoring` Application installs `kube-prometheus-stack` (Prometheus,
Grafana, kube-state-metrics, node-exporter) in the `monitoring` namespace.
`monitoring-addons` adds blackbox-exporter, HTTP probes, alert rules and the
Grafana admin SealedSecret. See [Monitoring](#monitoring).

Database migrations run as an Argo CD **`PreSync` Job**
(`manifest/base/app/jobs/db-migrate-job.yaml`). The FastAPI image no longer runs
`alembic upgrade head` at startup, so the schema is migrated exactly once before
the API Deployment rolls out and the API can be scaled to N replicas without
concurrent migrations.

### Install and bootstrap

```bash
./dev-setup/k8s/bootstrap_cluster.sh
```

The script installs Argo CD with server-side apply (required because the
ApplicationSet CRD exceeds the client-side annotation limit), restores the
Sealed Secrets key, creates the namespace, applies every `argocd/projects/*.yaml`
and the root Application.

The root Application creates the four child Applications. Their sync policy is
`automated` with `prune` and `selfHeal` enabled, so the cluster converges back
to Git after manual changes and resources removed from Git are pruned.

```bash
kubectl -n argocd get applications
kubectl -n argocd port-forward svc/argocd-server 8080:443
# UI: https://localhost:8080  (user: admin)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

The Applications track the `main` branch. The repository is public, so Argo CD
clones it over HTTPS without repository credentials.

## Monitoring

`kube-prometheus-stack` runs in the `monitoring` namespace with reduced
requests/limits and 3 days of retention. Alertmanager is intentionally disabled:
alerts are evaluated and visible in the Prometheus UI, but no notification is
routed. The k3s control-plane components (controller-manager, scheduler, etcd,
kube-proxy) are not scraped because k3s runs them embedded.

| Component | Namespace | Notes |
|---|---|---|
| Prometheus + Grafana | `monitoring` | Grafana on `http://grafana.localhost` |
| kube-state-metrics, node-exporter | `monitoring` | cluster / node metrics |
| blackbox-exporter | `monitoring` | HTTP probes for FastAPI and Virtuoso |
| postgres-exporter | `mudis-dev` | dedicated read-only `monitoring` Postgres role (`pg_monitor`) |
| redis-exporter | `mudis-dev` | no auth, Redis is internal only |

Grafana credentials come from the `grafana-admin` SealedSecret. To read the
password:

```bash
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
```

Prometheus is available with:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Known limits:

- FastAPI does not expose `/metrics`; it is monitored by availability/latency
  (`probe_success`, `probe_duration_seconds` on `/health`) and pod metrics, not
  by per-route HTTP counters.
- Virtuoso has no maintained Prometheus exporter; same blackbox approach on
  `/sparql`.
- The PostgreSQL, Redis and Node Exporter dashboards (grafana.com `9628`,
  `763`, `1860`) are vendored in
  `manifest/base/monitoring/postgres-redis-node-full-configmap.yaml` as
  ConfigMaps labelled `grafana_dashboard=1`. The Grafana sidecar provisions them,
  so they are read-only in the UI: change the exported JSON in Git instead. The
  kube-prometheus-stack defaults cover cluster, node, pod and API server views.
- Grafana's provider runs with `allowUiUpdates=false` and `disableDeletion=false`:
  removing a ConfigMap from Git removes its dashboard, and UI edits are refused
  (`400 Cannot save provisioned dashboard`).

## Docker Compose (reference)

The compose files and `dev-setup/generate_*_env.sh` templates are kept as a
reference for the pre-Kubernetes workflow. They reference the private images and
the private source tree, so they are not directly runnable from this repository
alone.

## Access

This is a portfolio/demonstration repository. For image access, credentials, or
the application source, contact the owner.
