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
manifest/
  base/            Kustomize base: ConfigMap, NetworkPolicies, storage,
                   Postgres / Virtuoso StatefulSets, FastAPI / Celery / Next
                   Deployments, Postgres backup CronJob
  overlays/k3d/    k3d overlay: namespace, image references, SealedSecrets
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

All images are tagged `1.0.0` in `manifest/overlays/k3d/kustomization.yaml`.

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
  committed as `SealedSecret` resources (see `manifest/base/secrets/README.md`)
  and decrypted by the controller at apply time;
- back up the controller's private key offline
  (`kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o yaml`).
  Losing it makes the committed `SealedSecret` resources undecryptable.

## GitOps (Argo CD)

Argo CD watches this repository and syncs the `platform` and `mudis`
Applications. Database migrations run as a `PreSync` Job, so the schema is
updated exactly once before the API Deployment rolls out — the API can then be
scaled to N replicas without concurrent migrations.

> Argo CD manifests are being added in a follow-up commit.

## Docker Compose (reference)

The compose files and `dev-setup/generate_*_env.sh` templates are kept as a
reference for the pre-Kubernetes workflow. They reference the private images and
the private source tree, so they are not directly runnable from this repository
alone.

## Access

This is a portfolio/demonstration repository. For image access, credentials, or
the application source, contact the owner.
