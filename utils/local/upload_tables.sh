#!/bin/bash

cd /app

if [ -n "$POSTGRES_PASSWORD" ]; then
    PASSWORD_ARG="--password $POSTGRES_PASSWORD"
else
    PASSWORD_ARG=""
fi

HOST_ARG="${POSTGRES_HOST:-postgis}"
DB_ARG="${POSTGRES_DB:-geodb}"
USER_ARG="${POSTGRES_USER:-admin}"

echo "Checking / uploading cos2018v4 table..."
poetry run python3 ./upload_tables.py --host "$HOST_ARG" --database "$DB_ARG" \
    --user "$USER_ARG" $PASSWORD_ARG --table cos2018v4 --input /data/cos2018v4.gpkg

echo "Checking / uploading cos2025v1 table..."
poetry run python3 ./upload_tables.py --host "$HOST_ARG" --database "$DB_ARG" \
    --user "$USER_ARG" $PASSWORD_ARG --table cos2025v1 --input /data/cos2025v1.gpkg

echo "Checking / uploading cadastralparcel table..."
poetry run python3 ./upload_tables.py --host "$HOST_ARG" --database "$DB_ARG" \
    --user "$USER_ARG" $PASSWORD_ARG --table cadastralparcel --input /data/inspire_mv_cadastralparcel_4326.gpkg

exit 0
