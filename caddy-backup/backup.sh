#!/usr/bin/env bash
set -euo pipefail

# Required environment variables:
# - S3_BUCKET            your S3 bucket name
# - S3_ACCESS_KEY_ID     S3 access key
# - S3_SECRET_ACCESS_KEY S3 secret key
# - S3_FOLDER            backup folder path in the bucket
# - S3_ENDPOINT          (optional) custom S3 endpoint URL (e.g. for R2, MinIO, etc.)
# - CADDY_DATA_DIR       directory to back up (e.g. /data or /etc/caddy)

: "${S3_BUCKET:?need to set S3_BUCKET}"
: "${S3_ACCESS_KEY_ID:?need to set S3_ACCESS_KEY_ID}"
: "${S3_SECRET_ACCESS_KEY:?need to set S3_SECRET_ACCESS_KEY}"
: "${S3_FOLDER:?need to set S3_FOLDER}"
: "${CADDY_DATA_DIR:?need to set CADDY_DATA_DIR}"

TS="$(date +'%Y-%m-%d_%H-%M')"
ARCHIVE="/tmp/caddy-backup-${TS}.tar.gz"

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"

echo "[+] Archiving Caddy data from ${CADDY_DATA_DIR} → ${ARCHIVE}"
tar -czf "${ARCHIVE}" -C "$(dirname "${CADDY_DATA_DIR}")" "$(basename "${CADDY_DATA_DIR}")"

UPLOAD_PATH="s3://${S3_BUCKET}/${S3_FOLDER}/caddy-backup-${TS}.tar.gz"
echo "[+] Uploading to S3: ${UPLOAD_PATH}"

AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY" aws --endpoint-url="$S3_ENDPOINT" s3 cp "$ARCHIVE" "$UPLOAD_PATH"

echo "[+] Done." 