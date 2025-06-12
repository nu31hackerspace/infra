# Caddy Backup

This folder contains a Docker image and script to back up the Caddy storage volume (`/caddy_storage`) to a Cloudflare R2 bucket.

## Usage

- Mount `/caddy_storage` from your host or Docker volume as read-only.
- Provide the following environment variables:
  - `R2_ACCOUNT_ID`: Your Cloudflare account ID
  - `R2_BUCKET`: The R2 bucket name
  - `BACKUP_FOLDER`: The folder/prefix in the bucket (e.g., `daily`, `hourly`)
- Provide secrets for:
  - `r2_backup_access_key_id`
  - `r2_backup_secret_access_key`

The backup script will archive the entire `/caddy_storage` directory and upload it to your R2 bucket.

## Example Docker Compose Service

```
  caddy-backup-daily:
    build: ./caddy-backup
    command: ["/usr/local/bin/backup.sh"]
    environment:
      - R2_ACCOUNT_ID=your_account_id
      - R2_BUCKET=your_bucket
      - BACKUP_FOLDER=daily
    secrets:
      - r2_backup_access_key_id
      - r2_backup_secret_access_key
    volumes:
      - /caddy_storage:/caddy_storage:ro
``` 