#!/usr/bin/env bash

env | grep -E '^(SRC_|DST_|TABLES|RETRY_|CRON_)' | sed 's/=/="/;s/$/"/' > /app/env.sh

CRON_SCHEDULE="${CRON_SCHEDULE:-0 6 * * *}"

echo "$CRON_SCHEDULE . /app/env.sh && /app/sync-script.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

echo "Schedule: $CRON_SCHEDULE"

exec crond -f -l 2