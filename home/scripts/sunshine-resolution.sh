#!/usr/bin/env bash

# This script sets the Hyprland resolution to match the Sunshine client.
# It expects arguments: WIDTH HEIGHT FPS
# Or environment variables: SUNSHINE_CLIENT_WIDTH, SUNSHINE_CLIENT_HEIGHT, SUNSHINE_CLIENT_FPS

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
    # Look for a socket in /tmp/hypr
    # We take the most recent directory that isn't .lock
    SIG=$(ls -t /tmp/hypr/ | grep -v "\.lock" | head -n 1)
    if [ -n "$SIG" ]; then
        export HYPRLAND_INSTANCE_SIGNATURE="$SIG"
    else
        echo "Could not find HYPRLAND_INSTANCE_SIGNATURE"
        exit 1
    fi
fi

# Find the first available monitor if not specified
# We use 'hyprctl monitors' to get the list.
# We target the first monitor found.
MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')

if [ -z "$MONITOR" ] || [ "$MONITOR" == "null" ]; then
    # Fallback if no monitor is active (unlikely if session is running, but possible if purely headless start)
    MONITOR="HEADLESS-1"
fi

echo "Setting resolution for $MONITOR to ${WIDTH}x${HEIGHT}@${FPS}"
hyprctl keyword monitor "$MONITOR, ${WIDTH}x${HEIGHT}@${FPS}, 0x0, 1"
