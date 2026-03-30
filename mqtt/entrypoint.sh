#!/usr/bin/env bash
set -euo pipefail

: "${MQTT_ADMIN_USER:?need to set MQTT_ADMIN_USER}"
: "${MQTT_ADMIN_PASSWORD:?need to set MQTT_ADMIN_PASSWORD}"

MQTT_PORT="${MQTT_PORT:-1883}"
DYNSEC_FILE="/mosquitto/data/dynsec.json"
CONF_FILE="/mosquitto/config/mosquitto.conf"

# Generate mosquitto.conf
cat > "${CONF_FILE}" <<EOF
listener ${MQTT_PORT}
allow_anonymous false

plugin /usr/lib/mosquitto_dynamic_security.so
plugin_opt_config_file ${DYNSEC_FILE}

persistence true
persistence_location /mosquitto/data/
log_dest stdout
log_type all
EOF

# Initialise dynamic security only on first boot (preserve existing device registrations)
if [ ! -f "${DYNSEC_FILE}" ]; then
    echo "[entrypoint] Initialising dynamic security plugin..."
    mosquitto_ctrl dynsec init "${DYNSEC_FILE}" "${MQTT_ADMIN_USER}" "${MQTT_ADMIN_PASSWORD}"
    echo "[entrypoint] Dynamic security initialised with admin user '${MQTT_ADMIN_USER}'."
else
    echo "[entrypoint] Dynamic security file already exists, skipping init."
fi

exec /usr/sbin/mosquitto -c "${CONF_FILE}"
