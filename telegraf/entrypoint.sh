#!/bin/bash
set -e

# Default to executing the passed command (e.g., "telegraf")
CMD="$@"

if [ -e /var/run/docker.sock ]; then
    SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    echo "Detected Docker socket GID: $SOCKET_GID"
    
    # Check if we are running as root to perform the switch
    if [ "$(id -u)" = "0" ]; then
         echo "Switching to user 'telegraf' with supplementary group GID $SOCKET_GID"
         
         # Use setpriv to run the command as telegraf user/group with the socket group added
         # --reuid=telegraf: Real User ID
         # --regid=telegraf: Real Group ID
         # --init-groups: Initialize supplementary groups from /etc/group (for telegraf user)
         # --groups=$SOCKET_GID: Add the docker socket group
         
         exec setpriv --reuid=telegraf --regid=telegraf --init-groups --groups="$SOCKET_GID" -- $CMD
    else
        echo "Not running as root, cannot switch users. Continuing as current user..."
    fi
fi

# Fallback: just execute the command if we didn't switch or socket missing causes issues
exec $CMD
