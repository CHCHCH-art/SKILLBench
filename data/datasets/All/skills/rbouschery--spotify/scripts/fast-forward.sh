#!/bin/bash
# Fast forward 10 seconds
# Usage: ./fast-forward.sh
# Output: New position or error

osascript <<'EOF'
tell application "Spotify"
    try
        if player state is stopped then
            return "ERROR:No track playing"
        end if
        set currentPos to player position
        set trackLen to (duration of current track) / 1000
        set newPos to currentPos + 10
        if newPos > trackLen then set newPos to trackLen
        set player position to newPos
        return "Position: " & player position & " seconds"
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
