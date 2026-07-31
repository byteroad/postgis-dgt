FROM alpine:3.19

RUN apk add --no-cache bash postgresql16-client gdal

WORKDIR /app

COPY export-gpkg.sh /app/export-gpkg.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /app/export-gpkg.sh /entrypoint.sh && \
    touch /var/log/cron.log

ENTRYPOINT ["/entrypoint.sh"]