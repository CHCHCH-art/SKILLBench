#!/bin/bash
# Open your library in Spotify
# Usage: ./open-library.sh
# Output: Success message or error

osascript <<'EOF'
try
    open location "spotify:collection"
    return "Opened your library"
on error errMsg
    return "ERROR:" & errMsg
end try
EOF
