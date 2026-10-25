# Changelog

The document for keep the track of all changes for the NU31 infrastructure.

## 25.10.2026

Move PostgreSQL data to Azure Database for PostgreSQL (`main.postgres.database.azure.com`).

`mqtt-logger` and the Grafana `MQTT history` datasource connect to Azure over TLS.
The `postgres-backup-weekly` service, the `postgres-backup` image and the `postgres`
target of the **Restore from backup** action are removed, Azure keeps its own backups.

## 14.10.2026

Remove the direct `MQTT` datasource from Grafana.

The `grafana-mqtt-datasource` plugin, its provisioned datasource and the
`MQTT explorer` dashboard are gone, and Grafana no longer joins `mqtt-net`.
MQTT data is available in Grafana through the `MQTT history` datasource only.

Fix the `Service logs` dashboard failing with "queries require at least one
regexp or equality matcher that does not have an empty-compatible value" when
every filter is set to `All`. The `service` and `node` filters now match `.+`
for `All`. `stack` stays `.*` so containers outside a swarm stack still show up.

## 08.10.2026

Bring back the `mqtt-logger` service, now with a retention limit.

It subscribes to `#` on the broker and records every message into the
`mqtt_store.mqtt_history` table in PostgreSQL. Messages older than 24 hours are
deleted every 10 minutes, so the table no longer grows unbounded. Grafana gets the
`MQTT history` datasource (read-only role `mqtt_history_reader`) and the
`MQTT history` dashboard, filterable with MQTT topic filters like `#` or `prismo/#`.

## 24.08.2026

Build all docker images on every pull request.

The image list moved into the reusable workflow `.github/workflows/build-images.yml`,
which runs on pull requests (build only) and is called by the deploy workflow with
`push: true`. Fixes the case when a broken Dockerfile was noticed only after the
merge into main.

Fix the loki image build: the loki base image is distroless, so `apk` is not
available. The image now only carries the config, and the new one-shot `loki-init`
service prepares the ownership of the loki data volume.

## 23.08.2026

Add centralized logging for all containers of the swarm.

The `alloy` service (global mode) collects the logs of every container through the
Docker API and pushes them to the new single node `loki` service. Grafana gets the
`Loki` datasource and the `Infra / Service logs` dashboard provisioned from files.
Logs are kept for 30 days.

## 19.04.2026 (2)

Open the port for PostgreSQL to world for connect to the PostgreSQL out of VM perimeter

## 19.04.2026

Remove write the machine health info into the MQTT topic, due to increasing the PostgreSQL table size.
Now the telegraf write the CPU/disk/mem/... info only into MongoDB.
