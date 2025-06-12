#!/usr/bin/env bash
set -euo pipefail

# Prefer secrets if present
if [ -f /run/secrets/r2_backup_access_key_id ]; then
  export AWS_ACCESS_KEY_ID="$(cat /run/secrets/r2_backup_access_key_id)"
fi
if [ -f /run/secrets/r2_backup_secret_access_key ]; then
  export AWS_SECRET_ACCESS_KEY="$(cat /run/secrets/r2_backup_secret_access_key)"
fi

: "${R2_ACCOUNT_ID:?need to set R2_ACCOUNT_ID}"
: "${R2_BUCKET:?need to set R2_BUCKET}"
: "${BACKUP_FOLDER:?need to set BACKUP_FOLDER}"

TS="$(date +'%Y-%m-%d_%H-%M')"
ARCHIVE="/tmp/caddy_storage-${TS}.tar.gz"

if [ ! -d /caddy_storage ]; then
  echo "[!] /caddy_storage does not exist or is not mounted!"
  exit 1
fi

echo "[+] Archiving /caddy_storage → ${ARCHIVE}"
tar -czf "$ARCHIVE" -C / caddy_storage

echo "[+] Uploading to R2: ${R2_BUCKET}/${BACKUP_FOLDER}/caddy_storage-${TS}.tar.gz"
aws \
  --endpoint-url="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
  s3 cp \
    "$ARCHIVE" \
    "s3://${R2_BUCKET}/${BACKUP_FOLDER}/caddy_storage-${TS}.tar.gz"

echo "[+] Done." 