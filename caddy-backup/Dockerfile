FROM alpine:3.20

RUN apk add --no-cache aws-cli bash ca-certificates tar

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh 