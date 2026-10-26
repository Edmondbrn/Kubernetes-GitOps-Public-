#!/usr/bin/env bash

set -euo pipefail

[ -f /etc/container_environment.env ] && set -a && . /etc/container_environment.env && set +a

DB_NAME_VAL="${POSTGRES_DB:?POSTGRES_DB not set}"
DB_USER="${POSTGRES_USER:?POSTGRES_USER not set}"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
DUMP_FILE="/backups/${DB_NAME_VAL}_${TIMESTAMP}.sql.gz"

echo "[$(date)] Starting backup of ${DB_NAME_VAL}"

export PGPASSWORD
PGPASSWORD="$(cat "${POSTGRES_PASSWORD_FILE:-/run/secrets/db_password_admin}")"

pg_dump -U "${DB_USER}" -d "${DB_NAME_VAL}" | gzip > "${DUMP_FILE}"

unset PGPASSWORD
echo "[$(date)] Backup complete: ${DUMP_FILE}"