# Grafana Restore Instructions

Based on the analysis of your `infra` project, here is how your Grafana backup and restore process works.

Your Grafana setup uses Docker Swarm. The stack is deployed as `infra` (as seen in `local_deploy.js`), so your Docker volume for Grafana is named **`infra_grafana-data`** (fixing the slight typo from `infra_grafan-data`).

Additionally, looking at the `grafana-backup/backup.sh` script, it specifically backs up the `/var/lib/grafana/grafana.db` file. Your `grafana.tar` (or `.tar.gz`) file contains this `grafana.db` file.

Follow these steps on your VPS to safely restore your data:

### 1. Locate the backup file on your VPS
Ensure your backup file (e.g., `grafana.tar` or `grafana-backup-YYYY-MM-DD.tar.gz`) is present on the VPS. 
*For the commands below, assume it is located in the current directory (`$(pwd)`).*

### 2. Scale down the Grafana service
To prevent data corruption or database locks while you overwrite the file, you must temporarily stop the Grafana container.
```bash
docker service scale infra_grafana=0
```

### 3. Restore the data into the Docker volume
We will run a temporary Alpine container that mounts the `infra_grafana-data` volume and extracts your tar file directly into it. 

Run the following command from the directory where your `grafana.tar` is located:
```bash
docker run --rm \
  -v infra_grafana-data:/target \
  -v $(pwd):/backup \
  alpine \
  sh -c "tar -xvf /backup/grafana.tar -C /target"
```
> **Note:** If your file is gzipped (e.g., `grafana.tar.gz`), use `tar -xzvf` instead.

### 4. Verify and Fix Permissions
Grafana typically runs under user ID `472`. When extracting files as root (the default in the Alpine container), the ownership might change. Fix the permissions of the database file just to be safe:
```bash
docker run --rm \
  -v infra_grafana-data:/target \
  alpine \
  chown 472:0 /target/grafana.db
```

### 5. Scale up the Grafana service
Once the `grafana.db` is restored and permissions are correct, start the Grafana service back up:
```bash
docker service scale infra_grafana=1
```

After a few seconds, you should be able to access your Grafana dashboard with all your restored configurations and dashboards!
