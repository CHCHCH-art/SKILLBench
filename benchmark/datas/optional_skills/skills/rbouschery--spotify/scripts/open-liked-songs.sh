#!/bin/bash
# Open and play your liked songs
# Usage: ./open-liked-songs.sh
# Output: Success message or error

osascript <<'EOF'
try
    open location "spotify:internal:collection:tracks"
    delay 1
    tell application "Spotify"
        play
    end tell
    delay 0.5
    tell application "Spotify"
        return "Playing liked songs: " & name of current track & " by " & artist of current track
    end tell
on error errMsg
    return "ERROR:" & errMsg
end try
EOF
