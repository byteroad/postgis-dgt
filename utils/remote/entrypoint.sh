#!/usr/bin/env bash

env | grep -E '^(SRC_|TABLE_LIST|OUTPUT_DIR|RETRY_|REMOTE_CRON_|PATH=)' | sed 's/=/="/;s/$/"/' > /app/env.sh

REMOTE_CRON_SCHEDULE="${REMOTE_CRON_SCHEDULE:-0 6 * * *}"

echo "$REMOTE_CRON_SCHEDULE . /app/env.sh && /app/export-gpkg.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

echo "Schedule: $REMOTE_CRON_SCHEDULE"

exec crond -f -l 2