#!/usr/bin/env bash
set -euo pipefail

# Prefer secrets if present
if [ -f /run/secrets/r2_backup_access_key_id ]; then
  export AWS_ACCESS_KEY_ID="$(cat /run/secrets/r2_backup_access_key_id)"
fi
if [ -f /run/secrets/r2_backup_secret_access_key ]; then
  export AWS_SECRET_ACCESS_KEY="$(cat /run/secrets/r2_backup_secret_access_key)"
fi
if [ -f /run/secrets/mongo_uri ]; then
  export MONGO_URI="$(cat /run/secrets/mongo_uri)"
fi

# Ensure these are set in your `docker run` env:
# - MONGO_URI          e.g. mongodb://user:pass@host:27017/db
# - R2_ACCOUNT_ID      your Cloudflare Account ID
# - R2_BUCKET          your R2 bucket name
# - R2_ACCESS_KEY_ID   R2 access key
# - R2_SECRET_ACCESS_KEY R2 secret key

: "${MONGO_URI:?need to set MONGO_URI}"
: "${R2_ACCOUNT_ID:?need to set R2_ACCOUNT_ID}"
: "${R2_BUCKET:?need to set R2_BUCKET}"

TS="$(date +'%Y-%m-%d_%H%M')"
ARCHIVE="/tmp/mongodump-${TS}.gz"

echo "[+] Dumping MongoDB → ${ARCHIVE}"
mongodump \
  --uri="${MONGO_URI}" \
  --archive="${ARCHIVE}" \
  --gzip

echo "[+] Uploading to R2: ${R2_BUCKET}/backups/mongodump-${TS}.gz"
aws \
  --endpoint-url="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
  s3 cp \
    "${ARCHIVE}" \
    "s3://${R2_BUCKET}/backups/mongodump-${TS}.gz"

echo "[+] Done." 