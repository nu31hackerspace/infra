# infra
The project with all scripts for setup my infractructure.

# MongoDB to Cloudflare R2 Backup Docker Image

This Docker image backs up a MongoDB database and uploads the backup to Cloudflare R2 using the AWS CLI.

## Usage

1. **Build the Docker image:**

   ```sh
   docker build -t mongo-r2-backup ./backup
   ```

2. **Run the container:**
Add all secrets localy and run the docker-stack.local.yml

## Required Environment Variables

- `MONGO_URI` - MongoDB connection string (e.g., `mongodb://user:pass@host:27017/?authSource=admin`)
- `R2_ACCOUNT_ID` - Cloudflare Account ID
- `R2_BUCKET` - Cloudflare R2 bucket name
- `R2_ACCESS_KEY_ID` - Cloudflare R2 access key
- `R2_SECRET_ACCESS_KEY` - Cloudflare R2 secret key

## How it works

- Dumps the MongoDB database to a compressed archive
- Uploads the archive to Cloudflare R2 using the AWS CLI

# Secrets

- `mongo_uri`
- `r2_backup_access_key_id`
- `r2_backup_secret_access_key`


## Restore database from backup
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