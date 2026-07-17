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

To generate views

```
poetry run python3 ./create_views.py --user postgres --password SOMEPASSWORD --table crus --column Municipio
```

# Data sync

The script ./utils/remote/sync-script.sh can be added to the cron of the host machine, in case database is not used as container. In that case following env variables must be added (check that are visible to cron!)

```
export SRC_HOST="remote-source.example.com"
export SRC_PORT="5432"
export SRC_DB="gis_source"
export SRC_USER="reader_user"
export SRC_PASSWORD="secure_source_password"

export DST_HOST="localhost"
export DST_PORT="5432"
export DST_DB="gis_destination"
export DST_USER="postgres"
export DST_PASSWORD="local_destination_password"

export TABLE_LIST="schema.table1 schema.table2 schema.table3"
export RETRY_COUNT="5"
export RETRY_DELAY="10"
```