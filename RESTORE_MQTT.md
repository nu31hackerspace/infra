# MQTT Restore Instructions

Based on the analysis of your `infra` project, here is how your MQTT backup and restore process works.

Your MQTT setup uses Docker Swarm. The stack is deployed as `infra` (as seen in `docker-stack.yml`), so your Docker volume for MQTT is named **`infra_mqtt-data`**.

Looking at the `mqtt-backup/backup.sh` script, it backs up the `/mosquitto/data` directory which contains your `dynsec.json` (Dynamic Security plugin configuration), certificates, and potentially `mosquitto.db` for persistence. The backup file uploaded to GCS is a `.tar.gz` archive containing a `data/` folder.

Follow these steps on your VPS to safely restore your MQTT data:

### 1. Locate the backup file on your VPS
Ensure your backup file (e.g., `mqtt-backup-YYYY-MM-DD_HH-MM.tar.gz`) is present on the VPS. 
*For the commands below, assume it is located in the current directory (`$(pwd)`) and is named `mqtt-backup.tar.gz`.*

### 2. Scale down the MQTT service
To prevent data corruption or database locks while you overwrite the data, you must temporarily stop the MQTT container.
```bash
docker service scale infra_mqtt=0
```

### 3. Restore the data into the Docker volume
We will run a temporary Alpine container that mounts the `infra_mqtt-data` volume and extracts your tar.gz file directly into it. Since the backup script archives the `data/` directory itself, we use `--strip-components=1` to ensure the contents are placed exactly at the root of the volume.

Run the following command from the directory where your backup is located:
```bash
docker run --rm \
  -v infra_mqtt-data:/target \
  -v $(pwd):/backup \
  alpine \
  sh -c "tar -xzvf /backup/mqtt-backup.tar.gz -C /target --strip-components=1"
```

### 4. Verify and Fix Permissions
Mosquitto runs under user ID `1883` (for the `mosquitto` user) in the `eclipse-mosquitto` image. When extracting files as root (the default in the Alpine container), the ownership might change. Fix the permissions of the restored data to be safe:
```bash
docker run --rm \
  -v infra_mqtt-data:/target \
  alpine \
  chown -R 1883:1883 /target
```

### 5. Scale up the MQTT service
Once the data is restored and permissions are correct, start the MQTT service back up:
```bash
docker service scale infra_mqtt=1
```

After a few seconds, you should be able to connect to your MQTT broker, and all your dynamic security configurations, users, and persisted messages will be fully restored!
