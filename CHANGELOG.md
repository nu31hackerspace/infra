# Changelog

The document for keep the track of all changes for the NU31 infrastructure.

## 19.04.2026

Remove write the machine health info into the MQTT topic, due to increasing the PostgreSQL table size.
Now the telegraf write the CPU/disk/mem/... info only into MongoDB.
