#!/bin/bash

# Ensure Poetry is installed and available in PATH
if ! command -v poetry &> /dev/null
then
    echo "Poetry could not be found. Please install Poetry first."
    exit
fi

if [ -n "$POSTGRES_PASSWORD" ]; then
    PASSWORD_ARG="--password $POSTGRES_PASSWORD"
else
    PASSWORD_ARG=""
fi

echo "Uploading cos2018v4 table"
# Load cos2018v4
poetry run python3 ./upload_tables.py --host postgis  --database $POSTGRES_DB \
    --user $POSTGRES_USER $PASSWORD_ARG --table cos2018v4 --input /data/cos2018v4.gpkg
echo "Uploading cos2025v1 table"
# Load cos2025v1
poetry run python3 ./upload_tables.py --host postgis  --database $POSTGRES_DB \
    --user $POSTGRES_USER $PASSWORD_ARG --table cos2025v1 --input /data/cos2025v1.gpkg
exit 0
