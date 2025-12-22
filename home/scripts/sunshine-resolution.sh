#!/usr/bin/env bash

# This script sets the Hyprland resolution to match the Sunshine client.
# It also ensures a headless monitor exists if no other monitor is active.
# Robust version with retries and logging.

LOG_FILE="/tmp/sunshine-resolution.log"
echo "--- Starting sunshine-resolution at $(date) ---" > "$LOG_FILE"

WIDTH=${1:-$SUNSHINE_CLIENT_WIDTH}
HEIGHT=${2:-$SUNSHINE_CLIENT_HEIGHT}
FPS=${3:-$SUNSHINE_CLIENT_FPS}

WIDTH=${WIDTH:-3840}
HEIGHT=${HEIGHT:-2160}
FPS=${FPS:-60}

echo "Target resolution: ${WIDTH}x${HEIGHT}@${FPS}" >> "$LOG_FILE"

# Retry loop for Hyprland socket
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Search in /run/user/$(id -u)/hypr and /tmp/hypr
    USER_RUNTIME_DIR="/run/user/$(id -u)/hypr"
    SIG=""
    if [ -d "$USER_RUNTIME_DIR" ]; then
        SIG=$(ls -t "$USER_RUNTIME_DIR" | grep -v "\.lock" | head -n 1)
    fi
    
    if [ -z "$SIG" ] && [ -d "/tmp/hypr" ]; then
        SIG=$(ls -t /tmp/hypr/ | grep -v "\.lock" | head -n 1)
    fi

    if [ -n "$SIG" ]; then
        export HYPRLAND_INSTANCE_SIGNATURE="$SIG"
        echo "Found HYPRLAND_INSTANCE_SIGNATURE=$SIG" >> "$LOG_FILE"
        
        # Test if hyprctl actually works
        if hyprctl version > /dev/null 2>&1; then
            echo "hyprctl is responsive" >> "$LOG_FILE"
            break
        else
            echo "hyprctl not yet responsive..." >> "$LOG_FILE"
        fi
    else
        echo "Waiting for Hyprland socket (retry $RETRY_COUNT)..." >> "$LOG_FILE"
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 1
done

if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo "ERROR: Could not find HYPRLAND_INSTANCE_SIGNATURE after $MAX_RETRIES seconds" >> "$LOG_FILE"
    exit 1
fi

# Consolidate environment for systemd
echo "Importing environment to systemd..." >> "$LOG_FILE"
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP

# Find the first available monitor
MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')

if [ -z "$MONITOR" ] || [ "$MONITOR" == "null" ]; then
    echo "No monitor found, creating headless output..." >> "$LOG_FILE"
    hyprctl output create headless
    sleep 2
    MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')
fi

if [ -z "$MONITOR" ] || [ "$MONITOR" == "null" ]; then
    echo "ERROR: Failed to create or find a monitor." >> "$LOG_FILE"
    exit 1
fi

echo "Setting resolution for $MONITOR to ${WIDTH}x${HEIGHT}@${FPS}" >> "$LOG_FILE"
hyprctl keyword monitor "$MONITOR, ${WIDTH}x${HEIGHT}@${FPS}, 0x0, 1" >> "$LOG_FILE" 2>&1

echo "Moving Workspace 1 to $MONITOR and switching to it..." >> "$LOG_FILE"
hyprctl dispatch moveworkspacetomonitor 1 "$MONITOR" >> "$LOG_FILE" 2>&1
hyprctl dispatch workspace 1 >> "$LOG_FILE" 2>&1

echo "Ensuring graphical-session.target is started..." >> "$LOG_FILE"
systemctl --user start graphical-session.target >> "$LOG_FILE" 2>&1

echo "Attempting to start Sunshine..." >> "$LOG_FILE"
systemctl --user start sunshine >> "$LOG_FILE" 2>&1

echo "--- Finished sunshine-resolution at $(date) ---" >> "$LOG_FILE"
