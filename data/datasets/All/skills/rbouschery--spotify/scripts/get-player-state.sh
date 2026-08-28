#!/bin/bash
# Get player state (playing/paused/stopped), position, and volume
# Usage: ./get-player-state.sh
# Output: state<<>>position<<>>volume<<>>shuffling<<>>repeating

osascript <<'EOF'
tell application "Spotify"
    try
        set currentState to player state as string
        set currentPosition to player position
        set currentVolume to sound volume
        set isShuffling to shuffling
        set isRepeating to repeating

        return currentState & "<<>>" & currentPosition & "<<>>" & currentVolume & "<<>>" & isShuffling & "<<>>" & isRepeating
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
