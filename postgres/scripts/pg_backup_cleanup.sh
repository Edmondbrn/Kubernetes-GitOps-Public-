#!/usr/bin/env bash
set -euo pipefail

echo "[$(date)] Cleaning backups older than 15 days"
find /backups -name "*.sql.gz" -mtime +15 -delete
echo "[$(date)] Cleanup complete"