FROM ubuntu:22.04

# Install AWS CLI for the S3-compatible upload
RUN apt-get update \
 && apt-get install -y --no-install-recommends awscli ca-certificates \
 && rm -rf /var/lib/apt/lists/*


RUN aws --version

# Copy in our backup script
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh