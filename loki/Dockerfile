FROM grafana/loki:3.5.1

# su-exec lets the entrypoint fix the volume ownership as root and then drop
# back to the unprivileged loki user (uid 10001) before starting Loki itself.
USER root
RUN apk add --no-cache su-exec

COPY loki-config.yml /etc/loki/config.yml
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3100

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["-config.file=/etc/loki/config.yml"]
