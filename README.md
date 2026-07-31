# PostGIS DGT

This repository provides a containerized **PostGIS** database setup alongside automated background services for local spatial data ingestion and remote GeoPackage data export.

## Services

* **`postgis`**: PostGIS spatial database instance.
* **`setup_local_db_and_listen`**: Runs on startup and periodically (configured via `LOCAL_CRON_SCHEDULE`) to import local shapefiles and GeoPackages from `./data` into PostGIS. Uses database metadata tracking to skip files that haven't changed.
* **`export_db_daily`**: Runs periodically (configured via `REMOTE_CRON_SCHEDULE`) to connect to a remote PostGIS database and export specified spatial tables as GeoPackage (`.gpkg`) files into `./data` using GDAL (`ogr2ogr`).

## Configuration

Create a `.env` file locally with the following format:

```env
POSTGRES_HOST="postgis"
POSTGRES_PORT="5432"
POSTGRES_DB="geodb"
POSTGRES_USER="admin"
POSTGRES_PASSWORD="admin"
POSTGRES_URL="postgresql://admin:admin@postgis:5432/geodb"

REMOTE_CRON_SCHEDULE="0 6 * * *"
LOCAL_CRON_SCHEDULE="*/10 * * * *"

SRC_HOST="postgis"
SRC_PORT="5432"
SRC_DB="geodb"
SRC_USER="admin"
SRC_PASSWORD="admin"

TABLE_LIST="public.cos2018v3"
OUTPUT_DIR="/data"

RETRY_COUNT=5
RETRY_DELAY=10
```

## License

This project is released under an [MIT License](./LICENSE).