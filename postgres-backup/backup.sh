#!/usr/bin/env bash
set -euo pipefail

# Required environment variables:
: "${PGHOST:?need to set PGHOST}"
: "${PGUSER:?need to set PGUSER}"
: "${PGPASSWORD:?need to set PGPASSWORD}"
: "${S3_BUCKET:?need to set S3_BUCKET}"
: "${S3_ACCESS_KEY_ID:?need to set S3_ACCESS_KEY_ID}"
: "${S3_SECRET_ACCESS_KEY:?need to set S3_SECRET_ACCESS_KEY}"
: "${S3_FOLDER:?need to set S3_FOLDER}"
: "${S3_ENDPOINT:?need to set S3_ENDPOINT}"

TS="$(date +'%Y-%m-%d_%H-%M')"
ARCHIVE="/tmp/pgdump-${TS}.sql.gz"

echo "[+] Dumping PostgreSQL → ${ARCHIVE}"
pg_dumpall -h "${PGHOST}" -U "${PGUSER}" | gzip > "${ARCHIVE}"

UPLOAD_PATH="s3://${S3_BUCKET}/${S3_FOLDER}/pgdump-${TS}.sql.gz"
echo "[+] Uploading to S3: ${UPLOAD_PATH}"

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"

aws --endpoint-url="$S3_ENDPOINT" s3 cp "$ARCHIVE" "$UPLOAD_PATH"

echo "[+] Done."
