#!/bin/bash -

# Set script to exit immediately if a command fails
set -e

# Display help information
function show_help {
  echo "Docker management utility"
  echo ""
  echo "Usage:"
  echo "  ./scripts/docker.sh [command]"
  echo ""
  echo "Commands:"
  echo "  start       Start all containers"
  echo "  clean-start Remove existing containers before starting up"
  echo "  stop        Stop all containers"
  echo "  restart     Restart all containers"
  echo "  build       Rebuild containers"
  echo "  logs        View logs from all containers"
  echo "  logs-back   View backend logs only"
  echo "  logs-front  View frontend logs only"
  echo "  logs-fuseki View fuseki logs only"
  echo "  shell-back  Open a shell in the backend container"
  echo "  shell-front Open a shell in the frontend container"
  echo "  ps          Show container status"
}

# Main command dispatcher
case "$1" in
  start)
    docker compose up -d
    ;;
  stop)
    docker compose down
    ;;
  restart)
    docker compose down
    docker compose up -d
    ;;
  clean-start)
    docker compose down --remove-orphans
    docker compose up -d --build
    ;;
  build)
    docker compose build
    ;;
  build-back)
    docker compose build fastapi_backend
    docker compose down
    docker compose up -d
    ;;
  logs)
    docker compose logs -f
    ;;
  logs-back)
    docker compose logs -f fastapi_backend
    ;;
  logs-front)
    docker compose logs -f next_frontend
    ;;
  logs-virtuoso)
    docker compose logs -f virtuoso
    ;;
  shell-back)
    docker compose exec fastapi_backend sh
    ;;
  shell-front)
    docker compose exec next_frontend sh
    ;;
  ps)
    docker compose ps
    ;;
  *)
    show_help
    ;;
esac