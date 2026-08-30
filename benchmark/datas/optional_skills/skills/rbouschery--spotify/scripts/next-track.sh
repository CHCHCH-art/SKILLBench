#!/bin/bash
# Skip to next track
# Usage: ./next-track.sh
# Output: Success message or error

osascript <<'EOF'
tell application "Spotify"
    try
        next track
        delay 0.5
        return "Skipped to: " & name of current track & " by " & artist of current track
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
