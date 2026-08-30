#!/bin/bash
# Toggle shuffle mode
# Usage: ./toggle-shuffle.sh
# Output: New shuffle state or error

osascript <<'EOF'
tell application "Spotify"
    try
        set shuffling to not shuffling
        if shuffling then
            return "Shuffle: ON"
        else
            return "Shuffle: OFF"
        end if
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
