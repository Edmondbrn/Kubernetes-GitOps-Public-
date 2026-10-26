#!/bin/bash

set -e

CONTAINER_NAME="fastapi_server"

echo "Current migration status:"
docker exec "${CONTAINER_NAME}" alembic current

echo ""
echo "Migration history:"
docker exec "${CONTAINER_NAME}" alembic history --verbose