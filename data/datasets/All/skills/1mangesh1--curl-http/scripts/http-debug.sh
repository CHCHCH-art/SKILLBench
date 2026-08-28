#!/bin/bash
# HTTP Request Debugger - Debug and test HTTP requests with detailed output
# Usage: ./http-debug.sh [METHOD] URL [DATA]

set -e

METHOD="${1:-GET}"
URL="${2}"
DATA="${3}"

if [ -z "$URL" ]; then
    echo "Usage: $0 [METHOD] <URL> [DATA]"
    echo "Example: $0 GET https://api.example.com/users"
    echo "Example: $0 POST https://api.example.com/users '{\"name\":\"John\"}'"
    exit 1
fi

echo "==================== HTTP Request Debug ===================="
echo "Method: $METHOD"
echo "URL: $URL"
echo ""

# Extract components from URL
PROTOCOL=$(echo "$URL" | cut -d: -f1)
DOMAIN=$(echo "$URL" | sed 's|^[^:]*://||' | cut -d/ -f1)
URL_PATH=$(echo "$URL" | sed 's|^[^:]*://[^/]*||')

echo "Protocol: $PROTOCOL"
echo "Domain: $DOMAIN"
echo "Path: ${URL_PATH:-/}"
echo ""

# Resolve DNS
echo "==================== DNS Resolution ===================="
dig +short "$DOMAIN" | head -5

echo ""
echo "==================== HTTP Headers ===================="

# Build curl command arguments array
CURL_ARGS=("-i" "-X" "$METHOD")

if [ -n "$DATA" ]; then
    CURL_ARGS+=("-d" "$DATA" "-H" "Content-Type: application/json")
fi

# Add verbose output
CURL_ARGS+=("-w" "\n\nResponse Time: %{time_total}s\n" "$URL")

echo "Command: curl ${CURL_ARGS[*]}"
echo ""
echo "==================== Response ===================="
curl "${CURL_ARGS[@]}"
