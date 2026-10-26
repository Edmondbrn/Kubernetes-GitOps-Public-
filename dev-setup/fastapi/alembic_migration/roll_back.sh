#!/bin/bash

set -e

CONTAINER_NAME="fastapi_server"
STEPS="${1:-1}"

echo "Rolling back ${STEPS} migration(s)..."
docker exec "${CONTAINER_NAME}" alembic downgrade -${STEPS}
echo "Rollback complete"