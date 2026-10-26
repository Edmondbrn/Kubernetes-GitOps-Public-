#!/bin/bash -

set -e
echo "The virtual environments mut be activated before the export."
pip freeze > fastapi_backend/requirements.txt
echo "Virtual environment export, done."