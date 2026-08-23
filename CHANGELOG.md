# Changelog

The document for keep the track of all changes for the NU31 infrastructure.

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
