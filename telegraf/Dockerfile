FROM telegraf:1.37.0

COPY telegraf.conf /etc/telegraf/telegraf.conf

USER root
RUN groupadd -g 998 docker && usermod -aG docker telegraf
USER telegraf
