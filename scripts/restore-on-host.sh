#!/usr/bin/env bash
set -euo pipefail

# Runs on the VPS (piped over ssh by the "Restore from backup" workflow).
#
# Usage: restore-on-host.sh <backup service> <backup file|latest> [service to stop...]
#
# The restore runs as a one-off container from the image of the deployed backup
# service, with that service's env, network and volumes. So the restore uses the
# same credentials, bucket folder and data volume as the backup, and no secret
# has to be sent from GitHub. The optional services are scaled to 0 during the
# restore (apps that would write to the database while it is replaced) and
# scaled back afterwards.

STACK="${STACK:-infra}"
BACKUP_SERVICE="${STACK}_${1:?need the backup service name}"
BACKUP_FILE="${2:-latest}"
shift 2 || shift $#

if ! docker service inspect "${BACKUP_SERVICE}" > /dev/null 2>&1; then
  echo "[!] Service ${BACKUP_SERVICE} not found, deploy the stack first."
  exit 1
fi

spec() { docker service inspect "${BACKUP_SERVICE}" --format "$1"; }

IMAGE="$(spec '{{.Spec.TaskTemplate.ContainerSpec.Image}}')"
ENV_FILE="$(umask 077 && mktemp)"
echo "BACKUP_FILE=${BACKUP_FILE}" > "${ENV_FILE}"
spec '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' >> "${ENV_FILE}"

# Services stopped for the restore, as "<name>=<replicas>", started again on exit.
STOPPED=()
cleanup() {
  rm -f "${ENV_FILE}"
  for entry in ${STOPPED[@]+"${STOPPED[@]}"}; do
    echo "[+] Starting ${entry%=*} again"
    docker service scale --detach=false "${entry}"
  done
}
trap cleanup EXIT

RUN_ARGS=()
# Only attachable networks can be joined by a plain container. The stack's
# implicit default network is not attachable, services that use only it
# need no internal network, just internet access, which the default bridge gives.
for network in $(spec '{{range .Spec.TaskTemplate.Networks}}{{.Target}} {{end}}'); do
  if [ "$(docker network inspect "${network}" --format '{{.Attachable}}')" = "true" ]; then
    RUN_ARGS+=(--network "${network}")
  else
    echo "[i] Skipping network ${network}, it is not attachable"
  fi
done
while read -r mount; do
  [ -n "${mount}" ] && RUN_ARGS+=(-v "${mount}")
done < <(spec '{{range .Spec.TaskTemplate.ContainerSpec.Mounts}}{{.Source}}:{{.Target}}{{println}}{{end}}')

for name in "$@"; do
  [ -z "${name}" ] && continue
  service="${STACK}_${name}"
  if ! docker service inspect "${service}" > /dev/null 2>&1; then
    echo "[i] Service ${service} not found, nothing to stop"
    continue
  fi
  replicas="$(docker service inspect "${service}" --format '{{.Spec.Mode.Replicated.Replicas}}')"
  echo "[+] Stopping ${service} (replicas ${replicas} -> 0)"
  STOPPED+=("${service}=${replicas}")
  docker service scale --detach=false "${service}=0"
done

echo "[+] Restoring with ${IMAGE}"
docker run --rm \
  --env-file "${ENV_FILE}" \
  ${RUN_ARGS[@]+"${RUN_ARGS[@]}"} \
  --entrypoint /usr/local/bin/restore.sh \
  "${IMAGE}"
