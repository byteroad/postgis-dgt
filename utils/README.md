# Data upload utility

This folder contains python scripts to upload Shapefiles to the PostGIS database and, if necessary, to create automatically SQL views.

To init the environment you need to install poetry, then run

```
poetry shell
poetry install
```

To load tables

```
poetry run python3 ./upload_tables.py --user postgres --password SOMEPASSWORD
```


# Data export (GeoPackage)

The script `./utils/remote/export-gpkg.sh` connects periodically to a remote PostGIS database and exports specified tables into GeoPackage format (`.gpkg`) using GDAL (`ogr2ogr`).

The following environment variables must be provided:

```bash
export SRC_HOST="remote-source.example.com"
export SRC_PORT="5432"
export SRC_DB="gis_source"
export SRC_USER="reader_user"
export SRC_PASSWORD="secure_source_password"

export TABLE_LIST="schema.table1 schema.table2 schema.table3"
export OUTPUT_DIR="/data"
export RETRY_COUNT="5"
export RETRY_DELAY="10"
```