#!/usr/bin/env sh
set -euo pipefail

# Required environment variables:
: "${CADDY_DATA_DIR:?need to set CADDY_DATA_DIR}"
: "${S3_BUCKET:?need to set S3_BUCKET}"
: "${S3_ACCESS_KEY_ID:?need to set S3_ACCESS_KEY_ID}"
: "${S3_SECRET_ACCESS_KEY:?need to set S3_SECRET_ACCESS_KEY}"
: "${S3_FOLDER:?need to set S3_FOLDER}"
: "${S3_ENDPOINT:?need to set S3_ENDPOINT}"

TS="$(date +'%Y-%m-%d_%H-%M')"
ARCHIVE="/tmp/caddy-backup-${TS}.tar.gz"

echo "[+] Archiving Caddy data from ${CADDY_DATA_DIR} → ${ARCHIVE}"
tar -czf "${ARCHIVE}" -C "$(dirname "${CADDY_DATA_DIR}")" "$(basename "${CADDY_DATA_DIR}")"




UPLOAD_PATH="s3://${S3_BUCKET}/${S3_FOLDER}/caddy-backup-${TS}.tar.gz"
echo "[+] Uploading to S3: ${UPLOAD_PATH}"

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"

aws --endpoint-url="$S3_ENDPOINT" s3 cp "$ARCHIVE" "$UPLOAD_PATH"

echo "[+] Done." 