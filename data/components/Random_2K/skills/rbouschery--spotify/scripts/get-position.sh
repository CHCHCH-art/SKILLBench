#!/bin/bash
# Get current playback position in seconds
# Usage: ./get-position.sh
# Output: Position in seconds or error

osascript <<'EOF'
tell application "Spotify"
    try
        if player state is stopped then
            return "ERROR:No track playing"
        end if
        return player position
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
