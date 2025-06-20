FROM alpine:3.19

RUN apk -Uuv add busybox-suid less aws-cli curl && \
	rm /var/cache/apk/*

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh