#!/bin/bash
# Get shuffle and repeat status
# Usage: ./get-modes.sh
# Output: shuffling<<>>repeating

osascript <<'EOF'
tell application "Spotify"
    try
        set isShuffling to shuffling
        set isRepeating to repeating
        return isShuffling & "<<>>" & isRepeating
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
