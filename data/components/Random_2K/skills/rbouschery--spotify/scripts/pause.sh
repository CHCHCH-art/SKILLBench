#!/bin/bash
# Pause playback
# Usage: ./pause.sh
# Output: Success message or error

osascript <<'EOF'
tell application "Spotify"
    try
        pause
        return "Playback paused"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
