#!/bin/bash -

set -e

# Interactive inputs
read -p "Enter the SQL database name: " DB_NAME
read -p "Enter the SQL database username: " DB_USER
read -p "Enter the Virtuoso HTTP port (default 8890): " VIRT_HTTP_INPUT
read -p "Enter the Virtuoso ISQL port (default 1111): " VIRT_ISQL_INPUT

VIRT_HTTP_PORT=${VIRT_HTTP_INPUT:-8890}
VIRT_ISQL_PORT=${VIRT_ISQL_INPUT:-1111}

echo "Generating single root .env file..."

cat <<EOF > .env
# Global / General
ENVIRONMENT=dev
ACCESS_TOKEN_NAME=access_token
REFRESH_TOKEN_NAME=refresh_token

# Next.js
NEXT_TELEMETRY_DEBUG=1
NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api/v1
NEXT_FAST_API_URL=http://fastapi_backend:8000

# PostgreSQL
DB_HOST=postgres
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_ADMIN_USER=admin_mudis4ls

# Virtuoso / RDF
VIRT_HTTP_PORT=$VIRT_HTTP_PORT
VIRT_ISQL_PORT=$VIRT_ISQL_PORT
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

# App admin settings
DB_APP_ADMIN_USER=app_admin
SEED_ADMIN_EMAIL=admin@example.com
SEED_ADMIN_USERNAME=Administrator

# Celery
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
EOF

echo "Root .env file generated successfully."

bash dev-setup/generate_secret.sh