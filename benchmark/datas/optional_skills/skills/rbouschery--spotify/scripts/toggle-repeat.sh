#!/bin/bash
# Toggle repeat mode
# Usage: ./toggle-repeat.sh
# Output: New repeat state or error

osascript <<'EOF'
tell application "Spotify"
    try
        set repeating to not repeating
        if repeating then
            return "Repeat: ON"
        else
            return "Repeat: OFF"
        end if
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
