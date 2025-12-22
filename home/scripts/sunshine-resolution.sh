#!/usr/bin/env bash

# This script sets the Hyprland resolution to match the Sunshine client.
# It also ensures a headless monitor exists if no other monitor is active.

WIDTH=${1:-$SUNSHINE_CLIENT_WIDTH}
HEIGHT=${2:-$SUNSHINE_CLIENT_HEIGHT}
FPS=${3:-$SUNSHINE_CLIENT_FPS}

if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ]; then
    echo "Usage: $0 <width> <height> [fps]"
    echo "Or set SUNSHINE_CLIENT_WIDTH and SUNSHINE_CLIENT_HEIGHT"
    exit 1
fi

FPS=${FPS:-60}

# Attempt to find the running Hyprland instance signature
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    # Search in /run/user/$(id -u)/hypr and /tmp/hypr
    USER_RUNTIME_DIR="/run/user/$(id -u)/hypr"
    if [ -d "$USER_RUNTIME_DIR" ]; then
        SIG=$(ls -t "$USER_RUNTIME_DIR" | grep -v "\.lock" | head -n 1)
    else
        SIG=$(ls -t /tmp/hypr/ | grep -v "\.lock" | head -n 1)
    fi

    if [ -n "$SIG" ]; then
        export HYPRLAND_INSTANCE_SIGNATURE="$SIG"
    else
        echo "Could not find HYPRLAND_INSTANCE_SIGNATURE"
        exit 1
    fi
fi

# Find the first available monitor
MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')

if [ -z "$MONITOR" ] || [ "$MONITOR" == "null" ]; then
    echo "No monitor found, creating headless output..."
    hyprctl output create headless
    sleep 2
    MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')
fi

if [ -z "$MONITOR" ] || [ "$MONITOR" == "null" ]; then
    echo "Failed to create or find a monitor."
    exit 1
fi

echo "Setting resolution for $MONITOR to ${WIDTH}x${HEIGHT}@${FPS}"
hyprctl keyword monitor "$MONITOR, ${WIDTH}x${HEIGHT}@${FPS}, 0x0, 1"