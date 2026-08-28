#!/bin/bash
# Launch Spotify application
# Usage: ./launch.sh
# Output: Success message or error

osascript <<'EOF'
tell application "Spotify"
    try
        activate
        return "Spotify launched"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
