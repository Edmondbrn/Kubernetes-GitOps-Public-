#!/bin/bash -

set -e

echo "Cleaning up test database..."

container_name="test_postgres_db"

if [ "$(docker ps -a --filter "name=^/${container_name}$" --format '{{.Names}}')" == "$container_name" ]; then
    docker exec -i test_postgres_db psql -U postgres -c "DROP DATABASE IF EXISTS test_postgres_db;"
    docker exec -i test_postgres_db psql -U postgres -c "CREATE DATABASE test_postgres_db;"
fi


echo "Cleaning over."