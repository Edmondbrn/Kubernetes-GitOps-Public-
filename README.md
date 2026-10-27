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
                   NetworkPolicies, storage, Postgres / Virtuoso / Redis / NFS
  base/app/        Application layer: FastAPI, Celery, Next.js, PreSync Job
  overlays/k3d/    k3d overlay: namespace + platform/app entry points
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
| `ghcr.io/edmondbrn/mudis_fastapi_prod`   | FastAPI + Celery  |
| `ghcr.io/edmondbrn/mudis_next_prod`      | Next.js           |
| `ghcr.io/edmondbrn/mudis_postgres_prod`  | PostgreSQL 18     |
| `ghcr.io/edmondbrn/mudis_virt_prod`      | OpenLink Virtuoso |

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

```bash
k3d cluster create mycluster --agents 2 --servers 1

# Sealed Secrets controller (the private key stays in the cluster)
kubectl apply -f https://github.com/bitnami/sealed-secrets/releases/download/v0.41.2/controller.yaml

# Namespace + GHCR pull secret (never committed)
kubectl create namespace mudis-dev
kubectl -n mudis-dev create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=edmondbrn \
  --docker-password=<PAT-with-read:packages>

kubectl apply -k manifest/overlays/k3d
kubectl -n mudis-dev get pods -w
```

Prerequisites:

- the four private images must be pullable (see above);
- the Sealed Secrets controller must be running — Kubernetes secrets are
  committed as `SealedSecret` resources (see `manifest/base/platform/secrets/README.md`)
  and decrypted by the controller at apply time;
- back up the controller's private key offline
  (`kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o yaml`).
  Losing it makes the committed `SealedSecret` resources undecryptable.

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
argocd/root-app.yaml            root Application -> argocd/apps/
argocd/projects/mudis.yaml      AppProject (repo + destination allow-list)
argocd/apps/platform.yaml       Application, sync-wave -1
argocd/apps/mudis.yaml          Application, sync-wave 0
```

The `platform` Application owns the namespace, storage, config, SealedSecrets,
Postgres, Redis, Virtuoso and the NFS server. The `mudis` Application owns the
FastAPI, Celery and Next.js workloads. Both currently target the `mudis-dev`
namespace.

Database migrations run as an Argo CD **`PreSync` Job**
(`manifest/base/app/jobs/db-migrate-job.yaml`). The FastAPI image no longer runs
`alembic upgrade head` at startup, so the schema is migrated exactly once before
the API Deployment rolls out and the API can be scaled to N replicas without
concurrent migrations.

### Install and bootstrap

```bash
# Argo CD v3.5.6 (server-side apply is required: the ApplicationSet CRD
# exceeds the client-side annotation limit)
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.6/manifests/install.yaml

# AppProject + root app
kubectl apply -f argocd/projects/mudis.yaml
kubectl apply -f argocd/root-app.yaml
```

The root Application creates the two child Applications. Their sync policy is
initially `automated` with `prune` and `selfHeal` disabled, so a bad sync cannot
delete cluster state while the deployment is being validated.

```bash
kubectl -n argocd get applications
kubectl -n argocd port-forward svc/argocd-server 8080:443
# UI: https://localhost:8080  (user: admin)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

The Applications track the `feature/prepare_k8s_config` branch until the
Kubernetes/GitOps work is merged; switch `targetRevision` to `main` afterwards.
The repository is public, so Argo CD clones it over HTTPS without repository
credentials.

## Docker Compose (reference)

The compose files and `dev-setup/generate_*_env.sh` templates are kept as a
reference for the pre-Kubernetes workflow. They reference the private images and
the private source tree, so they are not directly runnable from this repository
alone.

## Access

This is a portfolio/demonstration repository. For image access, credentials, or
the application source, contact the owner.
