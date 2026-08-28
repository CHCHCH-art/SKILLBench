#!/bin/bash
# Go to previous track
# Usage: ./previous-track.sh
# Output: Success message or error
# Note: If more than 3 seconds into track, goes to beginning of current track

osascript <<'EOF'
tell application "Spotify"
    try
        previous track
        delay 0.5
        return "Now playing: " & name of current track & " by " & artist of current track
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
