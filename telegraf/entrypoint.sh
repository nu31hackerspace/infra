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
         
         # Get existing groups for telegraf user (comma separated)
         EXISTING_GROUPS=$(id -Gn telegraf | tr ' ' ',')
         
         # Combine with the socket GID
         ALL_GROUPS="$EXISTING_GROUPS,$SOCKET_GID"
         
         # Use setpriv with explicit --groups list (merging existing + new)
         # We cannot use --init-groups with --groups
         
         exec setpriv --reuid=telegraf --regid=telegraf --groups="$ALL_GROUPS" -- $CMD
    else
        echo "Not running as root, cannot switch users. Continuing as current user..."
    fi
fi

# Fallback: just execute the command if we didn't switch or socket missing causes issues
exec $CMD
