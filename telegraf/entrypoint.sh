#!/bin/bash
set -e

if [ -e /var/run/docker.sock ]; then
    SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    echo "Detected Docker socket GID: $SOCKET_GID"
    
    # Check if a group with this GID already exists
    if ! getent group "$SOCKET_GID" > /dev/null; then
        echo "Creating group 'docker-socket' with GID $SOCKET_GID"
        groupadd -g "$SOCKET_GID" docker-socket
    fi
    
    # Get the group name (whether we created it or it existed)
    TARGET_GROUP=$(getent group "$SOCKET_GID" | cut -d: -f1)
    
    echo "Adding telegraf user to group '$TARGET_GROUP'"
    usermod -aG "$TARGET_GROUP" telegraf
fi

# Execute the original entrypoint or command
# The official Telegraf image uses /entrypoint.sh to drop privileges
if [ -f /entrypoint.sh ]; then
    exec /entrypoint.sh "$@"
else
    # Fallback if original entrypoint doesn't exist
    exec "$@"
fi
