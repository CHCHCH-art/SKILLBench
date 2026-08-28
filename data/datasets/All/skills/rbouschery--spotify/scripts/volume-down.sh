#!/bin/bash
# Decrease volume by 10
# Usage: ./volume-down.sh
# Output: New volume level or error

osascript <<'EOF'
tell application "Spotify"
    try
        set currentVol to sound volume
        set newVol to currentVol - 10
        if newVol < 0 then set newVol to 0
        set sound volume to newVol
        return "Volume: " & sound volume
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
