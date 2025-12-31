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

# We are running as root, so we need to manually drop privileges to 'telegraf'
# effectively after updating the groups.
# Note: standard /entrypoint.sh might reset or ignore our group changes if it uses setpriv strictly.

if [ "$1" = "telegraf" ]; then
    # We use 'setpriv' directly if available (standard in telegraf image) 
    # OR we can just run the command as the user.
    # The official image uses 'setpriv --reuid telegraf --init-groups ...' which MIGHT wipe our dynamic group.
    # So we should run the command directly as telegraf, preserving the new group.
    
    # Switch to telegraf user preserving the new supplementary groups
    exec su telegraf -c "$*"
else
    # Fallback for other commands
    exec "$@"
fi
