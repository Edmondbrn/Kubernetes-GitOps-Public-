#!/bin/bash

set -e

CONTAINER_NAME="fastapi_server"

echo "Applying migrations..."
docker exec "${CONTAINER_NAME}" alembic upgrade head
echo "Migrations applied"