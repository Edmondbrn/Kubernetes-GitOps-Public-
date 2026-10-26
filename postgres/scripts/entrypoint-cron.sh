#!/usr/bin/env bash


set -e

# Get environment variables to access to postgres
printenv | grep -Ev '^(HOME|PWD|SHLVL|_)=' > /etc/container_environment.env
chmod 600 /etc/container_environment.env

# Start cron daemon in the background
crond -b -L /var/log/cron.log

# Start postgress normally
exec docker-entrypoint.sh "$@"

