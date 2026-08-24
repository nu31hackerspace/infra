#!/bin/sh
set -e

# Docker creates the named volume mounted at /loki owned by root, but Loki runs
# as uid 10001. Create the data directories and hand them over before starting.
mkdir -p /loki/chunks /loki/rules /loki/rules-temp /loki/compactor /loki/wal
chown -R 10001:10001 /loki

exec su-exec 10001:10001 /usr/bin/loki "$@"
