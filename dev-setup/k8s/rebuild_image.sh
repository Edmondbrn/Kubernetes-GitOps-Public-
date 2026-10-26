#!/bin/bash -


set -e

# rebuild fastapi, nextJs and postgres image

cd fastapi_backend
docker build -t ghcr.io/<github-user>/holograph-backend:1.0.0 .
cd ..

cd postgres
docker build -t ghcr.io/<github-user>/holograph-postgres:1.0.0 .
cd ..

cd next_frontend
docker build -t ghcr.io/<github-user>/holograph-frontend:1.0.0 . --build-arg NEXT_PUBLIC_API_URL=/api/v1
cd ..

cd virtuoso
docker build -t ghcr.io/<github-user>/holograph-virtuoso:1.0.0 .
cd ..


k3d image import -c mycluster ghcr.io/<github-user>/holograph-virtuoso:1.0.0 ghcr.io/<github-user>/holograph-backend:1.0.0 ghcr.io/<github-user>/holograph-postgres:1.0.0 ghcr.io/<github-user>/holograph-frontend:1.0.0
kubectl rollout restart