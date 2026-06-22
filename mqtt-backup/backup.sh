#!/usr/bin/env bash
set -euo pipefail

: "${MQTT_DATA_DIR:?need to set MQTT_DATA_DIR}"
: "${GCS_BUCKET:?need to set GCS_BUCKET}"
: "${GCS_FOLDER:?need to set GCS_FOLDER}"
: "${GCS_SA_KEY_BASE64:?need to set GCS_SA_KEY_BASE64}"

DYNSEC_FILE="${MQTT_DATA_DIR}/dynsec.json"

if [ ! -f "${DYNSEC_FILE}" ]; then
    echo "Error: ${DYNSEC_FILE} does not exist. Nothing to back up."
    exit 1
fi

TS="$(date +'%Y-%m-%d_%H-%M')"
ARCHIVE="/tmp/mqtt-backup-${TS}.tar.gz"

echo "Archiving MQTT dynamic security config from ${MQTT_DATA_DIR} → ${ARCHIVE}"

tar -czf "${ARCHIVE}" -C "$(dirname "${MQTT_DATA_DIR}")" "$(basename "${MQTT_DATA_DIR}")"

# Authenticate to Google Cloud with the service account key (base64-encoded JSON).
export CLOUDSDK_CONFIG=/tmp/gcloud
KEY_FILE="$(mktemp)"
trap 'rm -f "${KEY_FILE}"' EXIT
echo "${GCS_SA_KEY_BASE64}" | base64 -d > "${KEY_FILE}"
gcloud auth activate-service-account --key-file="${KEY_FILE}"

UPLOAD_PATH="gs://${GCS_BUCKET}/${GCS_FOLDER}/mqtt-backup-${TS}.tar.gz"
echo "Uploading to GCS: ${UPLOAD_PATH}"
gcloud storage cp "${ARCHIVE}" "${UPLOAD_PATH}"

echo "Done."

exit 0
