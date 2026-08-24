# Changelog

The document for keep the track of all changes for the NU31 infrastructure.

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
