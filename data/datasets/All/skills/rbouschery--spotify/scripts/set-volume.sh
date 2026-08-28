#!/bin/bash
# Set volume level
# Usage: ./set-volume.sh <volume 0-100>
# Output: New volume level or error

VOLUME="${1:-}"

if [ -z "$VOLUME" ]; then
    echo "ERROR:Volume level is required (0-100)"
    exit 1
fi

# Validate volume is a number between 0 and 100
if ! [[ "$VOLUME" =~ ^[0-9]+$ ]] || [ "$VOLUME" -lt 0 ] || [ "$VOLUME" -gt 100 ]; then
    echo "ERROR:Volume must be a number between 0 and 100"
    exit 1
fi

osascript <<EOF
tell application "Spotify"
    try
        set sound volume to $VOLUME
        return "Volume set to " & sound volume
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
