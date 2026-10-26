#!/bin/bash

set -e

# Configuration
CONTAINER_NAME="fastapi_server"
MIGRATION_MESSAGE="${1:-initial schema}"

echo "🔍 Checking if container is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container '${CONTAINER_NAME}' is not running"
    echo "Start it with: docker-compose up -d ${CONTAINER_NAME}"
    exit 1
fi

echo "✅ Container is running"

# Check Alembic is installed
echo "🔍 Checking Alembic installation..."
if ! docker exec "${CONTAINER_NAME}" which alembic > /dev/null 2>&1; then
    echo "❌ Error: Alembic is not installed in the container"
    exit 1
fi

echo "Alembic is installed"

# Create migration
echo "Creating migration: ${MIGRATION_MESSAGE}"
docker exec "${CONTAINER_NAME}" alembic revision --autogenerate -m "${MIGRATION_MESSAGE}"

echo "Migration created successfully"

# Show the generated migration file
echo ""
echo "Generated migration file:"
# copy migration file form container to local host
docker cp fastapi_server:/app/alembic/versions/. fastapi_backend/alembic/versions
docker exec "${CONTAINER_NAME}" ls -lt /app/alembic/versions/ | head -n 2

# Ask to apply migration
read -p "Apply migration now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Applying migration..."
    docker exec "${CONTAINER_NAME}" alembic upgrade head
    echo "Migration applied successfully"
else
    echo "To apply later, run:"
    echo "   docker exec ${CONTAINER_NAME} alembic upgrade head"
fi