#!/bin/bash
# Quit Spotify application
# Usage: ./quit.sh
# Output: Success message or error

osascript <<'EOF'
tell application "Spotify"
    try
        quit
        return "Spotify quit"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
