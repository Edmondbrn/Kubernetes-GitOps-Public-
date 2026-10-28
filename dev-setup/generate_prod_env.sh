#!/bin/bash -

set -e


echo "Generating single root .env.prod file..."

cat <<EOF > .env.prod
# Global / General
ENVIRONMENT=prod
ACCESS_TOKEN_NAME=mudis4ls_access_token
REFRESH_TOKEN_NAME=mudis4ls_refresh_token
TZ=Europe

# Next.js
NEXT_TELEMETRY_DEBUG=1
NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api/v1
NEXT_FAST_API_URL=http://fastapi_backend:8000

# PostgreSQL
DB_HOST=postgres
DB_PORT=5432
DB_NAME=HolographSQL
DB_USER=app_user
DB_ADMIN_USER=admin_mudis4ls

# Virtuoso / RDF
VIRT_HTTP_PORT=8891
VIRT_ISQL_PORT=1111
VIRT_SPARQL_DEFAULTQUERY="select distinct ?Concept where {[] a ?Concept} LIMIT 100"
DOCKER_VIRTUOSO_URL=http://virtuoso:8890/sparql-auth
WEB_VIRTUOSO_URL=http://localhost:8890/sparql-auth

# Virtuoso Queue
VIRTUOSO_POOL_ENABLED=false
VIRTUOSO_LONG_MAX=3
VIRTUOSO_SHORT_MAX=10
VIRTUOSO_REDIS_URL=redis://redis:6379/2
VIRTUOSO_ACQUIRE_TIMEOUT=30

# FastAPI Security & JWT
JWT_ALGORITHM=HS256
REFRESH_TOKEN_EXPIRE_DAYS=7

# FastAPI Application / Defaults
DEBUG=false
SERVICE_NAME=api
LOG_DIR=/var/log/app
LOG_FILE_MAX_BYTES=10000000
LOG_FILE_BACKUP_COUNT=5
LOG_FILE_COMPRESS=true

# Rate Limiting
USER_RATE_LIMIT=100
ANON_RATE_LIMIT=20
RATE_LIMITER_REDIS_URL=redis://redis:6379/1

# Proxy Settings
TRUST_PROXY_HEADERS=false
TRUSTED_PROXY_CIDRS=""

# Celery
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# App admin settings
DB_APP_ADMIN_USER=app_admin
SEED_ADMIN_EMAIL=admin@example.com
SEED_ADMIN_USERNAME=Administrator

# Docker image
REGISTRY_IMAGE_BACKEND=ghcr.io/edmondbrn/holograph-web/mudis_fastapi_prod
REGISTRY_IMAGE_FRONTEND=ghcr.io/edmondbrn/holograph-web/mudis_next_prod
IMAGE_TAG=latest
EOF

echo "Root .env.prod file generated successfully."
bash dev-setup/generate_secret.sh