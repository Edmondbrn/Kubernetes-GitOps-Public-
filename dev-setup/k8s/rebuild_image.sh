#!/bin/bash -


set -e

# rebuild fastapi, nextJs and postgres image

cd fastapi_backend
docker build -t ghcr.io/edmondbrn/mudis_fastapi_prod:1.0.0 .
cd ..

cd postgres
docker build -t ghcr.io/edmondbrn/mudis_postgres_prod:1.0.0 .
cd ..

cd next_frontend
docker build -t ghcr.io/edmondbrn/mudis_next_prod:1.0.0 . --build-arg NEXT_PUBLIC_API_URL=/api/v1
cd ..

cd virtuoso
docker build -t ghcr.io/edmondbrn/mudis_virt_prod:1.0.0 .
cd ..


k3d image import -c mycluster ghcr.io/edmondbrn/mudis_virt_prod:1.0.0 ghcr.io/edmondbrn/mudis_fastapi_prod:1.0.0 ghcr.io/edmondbrn/mudis_postgres_prod:1.0.0 ghcr.io/edmondbrn/mudis_next_prod:1.0.0
kubectl rollout restart