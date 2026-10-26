FROM postgres:18-alpine

RUN apk add --no-cache findutils tzdata

COPY scripts/pg_backup.sh /scripts/pg_backup.sh
COPY scripts/pg_backup_cleanup.sh /scripts/pg_backup_cleanup.sh
COPY scripts/entrypoint-cron.sh /entrypoint-cron.sh
COPY crontab /etc/crontabs/root

RUN chmod +x /scripts/pg_backup.sh /scripts/pg_backup_cleanup.sh /entrypoint-cron.sh \
    && chmod 0644 /etc/crontabs/root \
    && mkdir -p /backups \
    && chown postgres:postgres /backups

ENTRYPOINT ["/entrypoint-cron.sh"]
CMD ["postgres"]