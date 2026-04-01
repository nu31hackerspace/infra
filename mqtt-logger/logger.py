#!/usr/bin/env python3
"""Subscribes to all MQTT topics and persists every message to PostgreSQL."""

import logging
import os
import sys
import time

import psycopg2
import paho.mqtt.client as mqtt

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)

MQTT_HOST = os.environ.get("MQTT_HOST", "mqtt")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_USER = os.environ["MQTT_USER"]
MQTT_PASSWORD = os.environ["MQTT_PASSWORD"]
MQTT_TOPIC = os.environ.get("MQTT_TOPIC", "#")

PGHOST = os.environ.get("PGHOST", "postgres-1")
PGPORT = int(os.environ.get("PGPORT", "5432"))
PGUSER = os.environ["PGUSER"]
PGPASSWORD = os.environ["PGPASSWORD"]
PGDATABASE = os.environ.get("PGDATABASE", "mqtt_store")

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS mqtt_messages (
    id          BIGSERIAL    PRIMARY KEY,
    topic       TEXT         NOT NULL,
    payload     BYTEA,
    qos         SMALLINT     NOT NULL,
    retain      BOOLEAN      NOT NULL,
    received_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
"""

INSERT_SQL = """
INSERT INTO mqtt_messages (topic, payload, qos, retain)
VALUES (%s, %s, %s, %s)
"""


def connect_pg():
    while True:
        try:
            conn = psycopg2.connect(
                host=PGHOST,
                port=PGPORT,
                user=PGUSER,
                password=PGPASSWORD,
                dbname=PGDATABASE,
            )
            conn.autocommit = True
            with conn.cursor() as cur:
                cur.execute(CREATE_TABLE_SQL)
            log.info("Connected to PostgreSQL (%s/%s), table ready.", PGHOST, PGDATABASE)
            return conn
        except Exception as exc:
            log.warning("PostgreSQL not ready (%s), retrying in 5s…", exc)
            time.sleep(5)


pg_conn = None


def get_cursor():
    global pg_conn
    if pg_conn is None or pg_conn.closed:
        pg_conn = connect_pg()
    return pg_conn.cursor()


def on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0:
        log.info("Connected to MQTT broker %s:%s, subscribing to '%s'", MQTT_HOST, MQTT_PORT, MQTT_TOPIC)
        client.subscribe(MQTT_TOPIC, qos=1)
    else:
        log.error("MQTT connection refused, reason code: %s", reason_code)


def on_message(client, userdata, msg):
    global pg_conn
    try:
        cur = get_cursor()
        cur.execute(INSERT_SQL, (msg.topic, msg.payload, msg.qos, msg.retain))
        cur.close()
        log.debug("Stored [%s] %d bytes", msg.topic, len(msg.payload or b""))
    except Exception as exc:
        log.error("Failed to store message from '%s': %s", msg.topic, exc)
        pg_conn = None


def main():
    global pg_conn
    pg_conn = connect_pg()

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.username_pw_set(MQTT_USER, MQTT_PASSWORD)
    client.on_connect = on_connect
    client.on_message = on_message

    while True:
        try:
            client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
            client.loop_forever()
        except Exception as exc:
            log.warning("MQTT error (%s), reconnecting in 5s…", exc)
            time.sleep(5)


if __name__ == "__main__":
    main()
