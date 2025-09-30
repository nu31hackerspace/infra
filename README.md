# Infra for pet project

We build real **uncloud** here.

The project with all scripts for setup an infrastructure for simple pet project, without over engineering, but with all required components,
such as backups for database, backup for reverse proxy etc.

The project prepares VPS for hosting docker stack by Ansible scripts. All infrastructure components deploy as docker services. Also configuration provides presetup docker networks.

## Infrastructure components

### Database

MongoDB is my database of choice. I believe it's the only data store which you need to build the project.
I use the mongodb bucket for BLOB store, it make local infracture easy to handle, and the API for mongo bucket easy to work compare to S3 buckets.

### Reverse proxy

The project provides **caddy** as reverse proxy for handle SSL key generation and allow you to host few services on one VPS.

### Periodic tasks

The `infra` stack has the cron executor `crazymax/swarm-cronjob` which is used for periodic backup database and caddy config

### Backups

The project provides periodic backups for mongo and caddy config.
The Database backups each hour, each day, and each week, all backups can be stored in any S3 compatible storage.

## Build & deploy

For more details, take a look at [project github action](https://github.com/VovaStelmashchuk/infra/tree/main/.github/workflows)

You can find all required environment variables and secrets for the project in the github action job `Create env file`. Also some secrets are provided as docker secrets, but I have been trying to get rid of docker secrets in the project.

## Local development

For local infrastructure use file `docker-stack.local.yml` - the file setup only mongo and mongo viewer

The setup is tested only for MacOS with `colima`

1. Start colima by command

In case `qemu` is not installed on your machine, install it by command `brew install qemu`

```bash
colima start --network-address
```

2. Verify colima status

```bash
colima status
```

The command will return information about colima virtual machine, look to the line `INFO[0000] address:`
Use the colima VM IP address to start the docker stack

```bash
docker swarm init --advertise-addr <IP address from the colima status command>
```

3. Run docker stack

```bash
docker stack deploy -c docker-stack.local.yml infra
```

The command will start the mongodb at port 27017 and mongo viewer on port 5000 into colima VM.

Open http://<colima ip>:5000 to browse the mongo db.

4. (Optional) Apply backup/snapshot of mongodb to your local environment

Copy mongo backup file into docker container

```bash
docker cp /path/to/backup/test.archive mongo:/test.archive
```

Restore mongo from backup

```bash
docker exec -it <mongo container> mongorestore --uri mongodb://localhost:27017 --gzip --archive=test.archive
```

### Restore database from backup

```
backups mongorestore \
  --host 167.235.52.168 \
  --port 2017 \
  --username <root_user_name> \
  --password '<pass for root>' \
  --authenticationDatabase admin \
  --drop \
  --gzip \
  --archive=backup-15-00.gz
```

### Local mongo, restore from any backup file

```
mongorestore --uri="mongodb://0.0.0.0:27017/" --drop --gzip --db=mixdrinks --archive=hourly_mongodump-2025-05-29_13-00.gz
```

## Local infrastructure

For the local infrastructure use the `docker-stack.local.yml`

```sh
docker stack deploy -c docker-stack.local.yml infra
```
