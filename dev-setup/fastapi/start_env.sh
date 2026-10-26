#!/bin/bash -


# Check if script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed."
    echo "Usage: source dev-setup/fastapi/start_env.sh"
    exit 1
fi

set -e
source ./fastapi_backend/.venv/bin/activate
echo "Virtual environment activated."