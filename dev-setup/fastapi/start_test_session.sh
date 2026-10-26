#!/bin/bash -
set -e

cleanup() {
    cd .. # return to the root project
    echo "Cleaning up test database..."
    docker compose -f docker-compose.test.yml down -v # erase the volume containing the database
}

trap cleanup EXIT # call cleanup function whent script ends

source dev-setup/fastapi/start_env.sh # start the virtual env

# create env variables for docker-compose.test.yml and test files
export ENVIRONMENT="dev"
export TEST_DAV_PASSWORD="testPwd"
export TEST_DBA_PASSWORD="testPwd"
export ACCESS_TOKEN_NAME="access_token"
export REFRESH_TOKEN_NAME="refresh_token"
export DB_USER="test_db_user"
export DB_PASSWORD_ANON="anon_pwd"
export DB_USER_PASSWORD="user_pwd"
export DB_PASSWORD_CRON="cron_pwd"
export DB_HOST="localhost"
export DB_PORT=5433
export DB_NAME="test_postgres_db"
export JWT_SECRET_KEY=$(openssl rand -base64 32)
export JWT_ALGORITHM="HS256"
export REFRESH_TOKEN_EXPIRE_DAYS=7
export DBA_PASSWORD="$TEST_DBA_PASSWORD"
export DOCKER_VIRTUOSO_URL="http://virtuoso_test:8891/sparql-auth"
export WEB_VIRTUOSO_URL="http://localhost:8891/sparql-auth"
export TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:$DB_PORT/$DB_NAME" # test database for migrations
export VIRTUOSO_POOL_ENABLED=false
export VIRTUOSO_LONG_MAX=3
export VIRTUOSO_SHORT_MAX=10
export VIRTUOSO_REDIS_URL="redis://localhost:6379/15"
export VIRTUOSO_ACQUIRE_TIMEOUT=30
export SERVICE_NAME="api_test"
export LOG_DIR="/var/log/app"
export RATE_LIMITER_REDIS_URL="redis://localhost:6379/14"
export CELERY_RESULT_BACKEND="redis://redis:6379/13"
export CELERY_BROKER_URL="redis://redis:6379/12"
export TRUST_PROXY_HEADERS=false
export TRUSTED_PROXY_CIDRS="" 
export NEXT_TELEMETRY_DEBUG=1
export NEXT_PUBLIC_API_BASE_URL=http://localhost:8000/api/v1
export NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1
export NEXT_FAST_API_URL=http://fastapi_backend:8000

export DB_APP_ADMIN_USER=app_admin
export DB_APP_ADMIN_PASSWORD=change-me-app-admin-password
export SEED_ADMIN_EMAIL=admin@example.com
export SEED_ADMIN_USERNAME=admin
export SEED_ADMIN_PASSWORD=Admin123!

docker compose -f docker-compose.test.yml up -d # start test database

echo "Waiting for PostgreSQL to be ready..."

until docker exec test_postgres_db pg_isready -U postgres -d test_postgres_db > /dev/null 2>&1; do
  sleep 1
done

echo "Waiting for Virtuoso to be ready..."

until curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:8891/sparql" | grep -q "200"; do
  sleep 1
done

echo "Loading Virtuoso test RDF graph..."

echo "Waiting for Virtuoso RDF data and inference rule set to be ready..."



echo "Applying Alembic migrations to test database..."
cd fastapi_backend
alembic upgrade head
pytest # start the test session
