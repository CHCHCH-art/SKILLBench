#!/bin/bash
# Resume playback
# Usage: ./play.sh
# Output: Success message or error

osascript <<'EOF'
tell application "Spotify"
    try
        play
        return "Playback resumed"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
