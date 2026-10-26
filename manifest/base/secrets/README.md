# Kubernetes secrets

Plaintext secrets are **never** committed to this repository.

They are delivered as [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets):
the cluster controller decrypts a `SealedSecret` into a normal `Secret` at apply
time, using a private key that never leaves the cluster.

Expected `SealedSecret` resources (namespace `mudis-dev`):

| SealedSecret            | Keys                    | Used by                     |
| ----------------------- | ----------------------- | --------------------------- |
| `dav-password`          | `dav-password`          | Virtuoso                    |
| `dba-password`          | `dba-password`          | Virtuoso                    |
| `db-password-admin`     | `db-password-admin`     | FastAPI, Postgres, backups  |
| `db-password-anon`      | `db-password-anon`      | FastAPI                     |
| `db-password-cron`      | `db-password-cron`      | FastAPI                     |
| `db-user-password`      | `db-user-password`      | FastAPI, Celery             |
| `db-app-admin-password` | `db-app-admin-password` | FastAPI                     |
| `jwt-secret-key`        | `jwt-secret-key`        | FastAPI                     |
| `seed-admin-password`   | `seed-admin-password`   | FastAPI                     |

## Generate a SealedSecret

```bash
kubectl create secret generic db-password-admin -n mudis-dev \
  --from-file=db-password-admin=./db_password_admin.txt \
  --dry-run=client -o yaml \
  | kubeseal --format yaml > db-password-admin-sealed.yaml
```

Commit only the `*-sealed.yaml` files.

> The controller's private key (`sealed-secrets-master-key.yaml`) is backed up
> offline by the owner and is gitignored. Without it, existing `SealedSecret`
> resources cannot be decrypted after a cluster rebuild.
