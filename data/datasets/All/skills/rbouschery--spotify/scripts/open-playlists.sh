#!/bin/bash
# Open your playlists in Spotify
# Usage: ./open-playlists.sh
# Output: Success message or error

osascript <<'EOF'
try
    open location "spotify:playlists"
    return "Opened your playlists"
on error errMsg
    return "ERROR:" & errMsg
end try
EOF
