FROM amazon/aws-cli:2.27.40

RUN yum install -y tar gzip

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh