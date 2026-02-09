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