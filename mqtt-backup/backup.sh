#!/usr/bin/env bash
set -euo pipefail

: "${MQTT_DATA_DIR:?need to set MQTT_DATA_DIR}"
: "${S3_BUCKET:?need to set S3_BUCKET}"
: "${S3_ACCESS_KEY_ID:?need to set S3_ACCESS_KEY_ID}"
: "${S3_SECRET_ACCESS_KEY:?need to set S3_SECRET_ACCESS_KEY}"
: "${S3_FOLDER:?need to set S3_FOLDER}"
: "${S3_ENDPOINT:?need to set S3_ENDPOINT}"

DYNSEC_FILE="${MQTT_DATA_DIR}/dynsec.json"

if [ ! -f "${DYNSEC_FILE}" ]; then
    echo "Error: ${DYNSEC_FILE} does not exist. Nothing to back up."
    exit 1
fi

TS="$(date +'%Y-%m-%d_%H-%M')"
ARCHIVE="/tmp/mqtt-backup-${TS}.tar.gz"

echo "Archiving MQTT dynamic security config from ${MQTT_DATA_DIR} → ${ARCHIVE}"

tar -czf "${ARCHIVE}" -C "$(dirname "${MQTT_DATA_DIR}")" "$(basename "${MQTT_DATA_DIR}")"

UPLOAD_PATH="s3://${S3_BUCKET}/${S3_FOLDER}/mqtt-backup-${TS}.tar.gz"
echo "Uploading to S3: ${UPLOAD_PATH}"

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"

aws --endpoint-url="$S3_ENDPOINT" s3 cp "$ARCHIVE" "$UPLOAD_PATH"

echo "Done."

exit 0
