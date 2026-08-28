#!/bin/bash
# Play specific Spotify URI or URL (track, album, or playlist)
# Usage: ./play-uri.sh <spotify_uri_or_url> [context_uri]
# Examples:
#   ./play-uri.sh "spotify:track:4uLU6hMCjMI75M1A2tKUQC"
#   ./play-uri.sh "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"
#   ./play-uri.sh "spotify:album:7ppypgQppMf3mkRbZxYIFM"
#   ./play-uri.sh "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"
#   ./play-uri.sh "spotify:track:xxx" "spotify:album:yyy"  # Play track in album context
# Output: Success message or error

INPUT="${1:-}"
CONTEXT="${2:-}"

if [ -z "$INPUT" ]; then
    echo "ERROR:Spotify URI or URL is required"
    exit 1
fi

# Convert URL to URI if needed
if [[ "$INPUT" == https://open.spotify.com/* ]]; then
    # Extract type and ID from URL
    # URL format: https://open.spotify.com/TYPE/ID?si=xxx
    TYPE=$(echo "$INPUT" | sed -E 's|https://open.spotify.com/([^/]+)/.*|\1|')
    ID=$(echo "$INPUT" | sed -E 's|https://open.spotify.com/[^/]+/([^?]+).*|\1|')
    URI="spotify:${TYPE}:${ID}"
else
    URI="$INPUT"
fi

if [ -n "$CONTEXT" ]; then
    osascript <<EOF
tell application "Spotify"
    try
        play track "$URI" in context "$CONTEXT"
        -- Wait for playback to start with retries
        repeat 10 times
            delay 0.3
            if player state is playing then exit repeat
        end repeat
        -- Try to get track info, but don't fail if unavailable
        try
            return "Playing: " & name of current track & " by " & artist of current track
        on error
            return "Playing: (track info loading)"
        end try
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
else
    osascript <<EOF
tell application "Spotify"
    try
        play track "$URI"
        -- Wait for playback to start with retries
        repeat 10 times
            delay 0.3
            if player state is playing then exit repeat
        end repeat
        -- Try to get track info, but don't fail if unavailable
        try
            return "Playing: " & name of current track & " by " & artist of current track
        on error
            return "Playing: (track info loading)"
        end try
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
fi
