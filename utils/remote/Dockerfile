FROM alpine:3.19

RUN apk add --no-cache bash postgresql16-client

WORKDIR /app

COPY sync-script.sh /app/sync-script.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /app/sync-script.sh /entrypoint.sh && \
    touch /var/log/cron.log

ENTRYPOINT ["/entrypoint.sh"]