#!/bin/bash
# Rewind 10 seconds
# Usage: ./rewind.sh
# Output: New position or error

osascript <<'EOF'
tell application "Spotify"
    try
        if player state is stopped then
            return "ERROR:No track playing"
        end if
        set currentPos to player position
        set newPos to currentPos - 10
        if newPos < 0 then set newPos to 0
        set player position to newPos
        return "Position: " & player position & " seconds"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
