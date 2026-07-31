FROM acidrain/python-poetry:3.9-1.8.4

RUN apt-get update && apt-get install -y --no-install-recommends cron && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml poetry.lock* /app/

RUN poetry install --no-root

COPY . /app

RUN chmod +x /app/upload_tables.sh /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
