#!/bin/bash
# Toggle play/pause
# Usage: ./toggle-playback.sh
# Output: New state or error

osascript <<'EOF'
tell application "Spotify"
    try
        playpause
        if player state is playing then
            return "Now playing"
        else
            return "Now paused"
        end if
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
