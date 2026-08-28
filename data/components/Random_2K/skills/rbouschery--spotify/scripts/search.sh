#!/bin/bash
# Open Spotify search for a query
# Usage: ./search.sh <query>
# Examples:
#   ./search.sh "bohemian rhapsody"
#   ./search.sh "artist:queen"
#   ./search.sh "album:a night at the opera"
#   ./search.sh "genre:jazz"
# Output: Success message or error

QUERY="${1:-}"

if [ -z "$QUERY" ]; then
    echo "ERROR:Search query is required"
    exit 1
fi

# URL encode the query
ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")

osascript <<EOF
try
    open location "spotify:search:$ENCODED_QUERY"
    return "Searching for: $QUERY"
on error errMsg
    return "ERROR:" & errMsg
end try
EOF
