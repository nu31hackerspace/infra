# Infra for pet project

We build real **uncloud** here.

The project with all scripts for setup a infractructure for simple pet project, without over enginiring, but with require attribute,
such as backups for database, backup for reverse proxy etc.

The project deploy all infracstrucute as docker stack with service as networks.

# MongoDB to any S3 Backup Docker Image

This Docker image backs up a MongoDB database and uploads the backup to any s3 using the AWS CLI.

## Usage

The project build 3 internal images.

- caddy - the reverse proxy of choose
- caddy-backup - the container for backup the caddy files to s3 bucket
- mongo-backup - the container for backup the mongo db directory to s3 bucket

## Build & deploy

For more details, take a look at [project github action](https://github.com/VovaStelmashchuk/infra/tree/main/.github/workflows)

You can find all required envirment variable and secrets for the project into github action job `Create env file`, Also some secret provide as docker secret, but I have been trying to get rid of docker secrets in the project.

## Mongo backup

### How mongo backup works

- Dumps the MongoDB database to a compressed archive
- Uploads the archive to Cloudflare R2 using the AWS CLI

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
