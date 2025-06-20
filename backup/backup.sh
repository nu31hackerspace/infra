#!/usr/bin/env bash
set -euo pipefail

# Ensure these are set in your `docker run` env:
# - MONGO_URI            e.g. mongodb://user:pass@host:27017/db
# - S3_BUCKET            your S3 bucket name
# - S3_ACCESS_KEY_ID     S3 access key
# - S3_SECRET_ACCESS_KEY S3 secret key
# - S3_FOLDER            backup folder path in the bucket
# - S3_ENDPOINT          (optional) custom S3 endpoint URL (e.g. for R2, MinIO, etc.)

: "${MONGO_URI:?need to set MONGO_URI}"
: "${S3_BUCKET:?need to set S3_BUCKET}"
: "${S3_ACCESS_KEY_ID:?need to set S3_ACCESS_KEY_ID}"
: "${S3_SECRET_ACCESS_KEY:?need to set S3_SECRET_ACCESS_KEY}"
: "${S3_FOLDER:?need to set S3_FOLDER}"
: "${S3_ENDPOINT:?need to set S3_ENDPOINT}"

TS="$(date +'%Y-%m-%d_%H-%M')"
ARCHIVE="/tmp/mongodump-${TS}.gz"

echo "[+] Dumping MongoDB → ${ARCHIVE}"
mongodump \
  --uri="${MONGO_URI}" \
  --archive="${ARCHIVE}" \
  --gzip

UPLOAD_PATH="s3://${S3_BUCKET}/${S3_FOLDER}/mongodump-${TS}.gz"
echo "[+] Uploading to S3: ${UPLOAD_PATH}"

aws --endpoint-url="$S3_ENDPOINT" \
  --access-key-id="$S3_ACCESS_KEY_ID" \
  --secret-access-key="$S3_SECRET_ACCESS_KEY" \
  s3 cp "$ARCHIVE" "$UPLOAD_PATH"

echo "[+] Done." 