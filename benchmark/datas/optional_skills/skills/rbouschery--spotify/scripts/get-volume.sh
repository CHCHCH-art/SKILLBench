#!/bin/bash
# Get current volume level
# Usage: ./get-volume.sh
# Output: Volume level (0-100) or error

osascript <<'EOF'
tell application "Spotify"
    try
        return sound volume
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
