# README

The docker compose file contains a Postgis instance and a script to upload two shapefiles.

Create an .env file locally with following format:

```
POSTGRES_HOST="postgis"
POSTGRES_PORT="5432"
POSTGRES_DB="geodb"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres"
POSTGRES_URL=postgresql://postgres:postgres@postgis:5432/geodb
```


## License

This project is released under an [MIT License](./LICENSE)