#!/usr/bin/env bash
# cURL HTTP Request Testing
# Common API testing patterns with curl

test_api_endpoint() {
    local method="$1"
    local url="$2"
    local data="$3"
    
    echo "=== Testing API Endpoint ==="
    echo "Method: $method"
    echo "URL: $url"
    echo ""
    
    case "$method" in
        GET)
            curl -s -X GET "$url" \
                -H "Accept: application/json" | jq '.'
            ;;
        POST)
            curl -s -X POST "$url" \
                -H "Content-Type: application/json" \
                -d "$data" | jq '.'
            ;;
        PUT)
            curl -s -X PUT "$url" \
                -H "Content-Type: application/json" \
                -d "$data" | jq '.'
            ;;
        DELETE)
            curl -s -X DELETE "$url"
            ;;
    esac
}

# Test with authorization
test_with_auth() {
    local token="$1"
    local url="$2"
    
    curl -s -X GET "$url" \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" | jq '.'
}

# Usage example
test_api_endpoint "GET" "https://api.example.com/users"
