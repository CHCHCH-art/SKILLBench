#!/bin/bash
# Check if Spotify is running
# Usage: ./is-running.sh
# Output: true or false

osascript <<'EOF'
tell application "System Events"
    if (name of processes) contains "Spotify" then
        return "true"
    else
        return "false"
    end if
end tell
EOF
