#!/bin/bash
# Seek to specific position in track
# Usage: ./set-position.sh <seconds>
# Output: New position or error

POSITION="${1:-}"

if [ -z "$POSITION" ]; then
    echo "ERROR:Position in seconds is required"
    exit 1
fi

# Validate position is a number
if ! [[ "$POSITION" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo "ERROR:Position must be a number (seconds)"
    exit 1
fi

osascript <<EOF
tell application "Spotify"
    try
        if player state is stopped then
            return "ERROR:No track playing"
        end if
        set player position to $POSITION
        return "Position: " & player position & " seconds"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
