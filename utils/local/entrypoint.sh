#!/usr/bin/env bash

# Export environment variables for cron
env | grep -E '^(POSTGRES_|LOCAL_CRON_|PATH=)' | sed 's/=/="/;s/$/"/' > /app/env.sh

# Run once on container startup
echo "[INFO] Running initial import on container startup..."
/app/upload_tables.sh

# Configure cron schedule (every 10 minutes default)
LOCAL_CRON_SCHEDULE="${LOCAL_CRON_SCHEDULE:-*/10 * * * *}"

echo "$LOCAL_CRON_SCHEDULE . /app/env.sh && /app/upload_tables.sh >> /var/log/cron.log 2>&1" | crontab -

touch /var/log/cron.log
echo "[INFO] Cron schedule set to: $LOCAL_CRON_SCHEDULE"

exec cron -f
