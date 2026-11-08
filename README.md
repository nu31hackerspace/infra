# Infra for pet project

**Keep in mind, now infra project works with new VM all changes will apply to VM by ${HOST} variable.**

---

We build real **uncloud** here.

The project with all scripts for setup an infrastructure for simple pet project, without over engineering, but with all required components, such as backups for database, backup for reverse proxy etc.

The project prepares VPS for hosting docker stack by Ansible scripts. All infrastructure components deploy as docker services. Also configuration provides presetup docker networks. 

So basicly you just rent any VPS or setup the ubunut server your self, and have it up and running for few minutes.

The project provides all infrastruture require to implement simple pet projects without over engineering. All setup of VPS done with infrastructure as code approatch which help you replicate the infra on any ubuntu server without pain.

The infrastructure includes the following:
- Docker Swarm
- Postgress
- Caddy reverse proxy
- Live logs for every container ([Dozzle](https://github.com/amir20/dozzle))

## Infrastructure components

### Reverse proxy

The project provides **caddy** as reverse proxy for handle SSL key generation and allow you to host few services on one VPS.

### Database

PostgreSQL lives in Azure Database for PostgreSQL (`main.postgres.database.azure.com`), outside
the stack. Services connect to it directly with the shared `USERNAME` + `PASSWORD`.

### Logs

Container logs are browsed live with **[Dozzle](https://github.com/amir20/dozzle)** at
`https://logs.nu31.space` (`dozzle` service, proxied by Caddy). Logs are not shipped or stored
anywhere: Dozzle reads them straight from the Docker API, so you see what `docker logs` keeps
on the node.

- Runs in `global` mode with `DOZZLE_MODE=swarm`: one instance per node, the instances find each
  other over the `dozzle-net` overlay network and the UI shows the containers of every node,
  grouped by stack and service.
- Login is the shared `USERNAME` + `PASSWORD`. The deploy workflow turns them into a
  `users.yml` (`dozzle generate`) and passes it as the swarm secret `dozzle-users-<commit sha>`.
  Secrets are immutable, so each deploy creates a new one; old ones can be removed with
  `docker secret ls` / `docker secret rm` (secrets in use are refused).

### Periodic tasks

The `infra` stack has the cron executor `crazymax/swarm-cronjob` which runs the periodic MQTT backup and the hourly `docker system prune`

### Backups

The MQTT broker data (`mqtt-data` volume) is backed up every day to a Google Cloud Storage bucket
(`mqtt-backup-daily`). Restore steps are in `RESTORE_MQTT.md`.

Backups authenticate with a Google Cloud service account that has the `Storage Object Admin` role on the bucket. Provide its credentials to the deploy as:

- `vars.GCS_BUCKET` — the destination bucket name (no `gs://` prefix).
- `secrets.GCS_SA_KEY_BASE64` — the service account JSON key, base64-encoded (e.g. `base64 -w0 key.json`).

PostgreSQL is not backed up by the stack, Azure Database for PostgreSQL keeps its own backups.

## Build & deploy

Two workflows:

- `.github/workflows/build-images.yml` holds the list of all images of the infra.
  It runs on **every pull request** and only builds the images, so a broken
  Dockerfile is caught in the pull request instead of breaking the deploy of main.
  One failing image does not cancel the others (`fail-fast: false`).
- `.github/workflows/deploy-infra.yml` runs on push to `main`. It calls
  `build-images.yml` with `push: true` to build and push all images to ghcr.io,
  and then deploys the stack over ssh.

Because both flows use the same image list, a green pull request means the deploy
will build the same set of images successfully.

For more details, take a look at [project github action](https://github.com/VovaStelmashchuk/infra/tree/main/.github/workflows)

You can find all required environment variables and secrets for the project in the github action job `Create env file`. Also some secrets are provided as docker secrets, but I have been trying to get rid of docker secrets in the project.

To create own infrastructure setup, fork the repository and update all need github action secrets and variables.

## MQTT

# Read (subscribe, streams messages until Ctrl+C)
node mqtt.js --mode=read --topic=my/topic

# Write (publish one message and exit)
node mqtt.js --mode=write --topic=my/topic --message="hello world"

### MQTT history

The `mqtt-logger` service (`mqtt-logger/logger.ts`) subscribes to `#` and stores every
message into the `mqtt_history` table of the `mqtt_store` PostgreSQL database. Messages
are kept for **24 hours** (`RETENTION_HOURS`), older rows are deleted every 10 minutes.

Open the **MQTT history** dashboard in Grafana and type a topic filter into the
`Topic` box, using the same syntax as an MQTT subscription:

| filter                  | shows                                      |
| ----------------------- | ------------------------------------------ |
| `#`                     | every topic                                |
| `prismo/#`              | `prismo` and everything below it           |
| `sensors/+/temperature` | one level wildcard                         |
| `prismo/door/state`     | exactly that topic                         |

The same filter works in your own SQL through the `mqtt_topic_matches(topic, filter)`
function:

```sql
SELECT received_at, topic, payload
FROM mqtt_history
WHERE mqtt_topic_matches(topic, 'prismo/#')
ORDER BY received_at DESC;
```

### Create a topic and a user for it

Users and their permissions live in the mosquitto dynamic security plugin
(`dynsec.json` in the `mqtt-data` volume), so they can be added on the running
broker, no restart needed. MQTT has no "create topic" step: a topic is a role that
allows publish + subscribe on `<topic>/#`, given to a new user.

Run on the VPS (replace `sensors/kitchen` and `kitchen-esp`):

```sh
docker exec -it $(docker ps -qf name=infra_mqtt.1) sh -c '
  mosquitto_ctrl -u "$MQTT_ADMIN_USER" -P "$MQTT_ADMIN_PASSWORD" dynsec createRole topic:sensors/kitchen &&
  mosquitto_ctrl -u "$MQTT_ADMIN_USER" -P "$MQTT_ADMIN_PASSWORD" dynsec addRoleACL topic:sensors/kitchen publishClientSend "sensors/kitchen/#" allow &&
  mosquitto_ctrl -u "$MQTT_ADMIN_USER" -P "$MQTT_ADMIN_PASSWORD" dynsec addRoleACL topic:sensors/kitchen subscribePattern "sensors/kitchen/#" allow &&
  mosquitto_ctrl -u "$MQTT_ADMIN_USER" -P "$MQTT_ADMIN_PASSWORD" dynsec createClient kitchen-esp &&
  mosquitto_ctrl -u "$MQTT_ADMIN_USER" -P "$MQTT_ADMIN_PASSWORD" dynsec addClientRole kitchen-esp topic:sensors/kitchen'
```

`createClient` asks for the new user's password. The device then connects to
`mqtts://mqtt.nu31.space:8883` with these credentials and can publish and subscribe on
`sensors/kitchen/#` only, any other topic is denied.

To give one more user access to an existing topic, run only the last two commands.
To check the result, open a shell in the broker container
(`docker exec -it $(docker ps -qf name=infra_mqtt.1) sh`) and run:

```sh
mosquitto_ctrl -u "$MQTT_ADMIN_USER" -P "$MQTT_ADMIN_PASSWORD" dynsec listClients
mosquitto_ctrl -u "$MQTT_ADMIN_USER" -P "$MQTT_ADMIN_PASSWORD" dynsec getRole topic:sensors/kitchen
```
