#!/usr/bin/env bash
# HTTP Response Analyzer
# Debug HTTP responses and headers

analyze_response() {
    local url="$1"
    
    echo "=== HTTP Response Analysis ==="
    
    # Get headers and body separately
    curl -s -w "\n\n=== Response Headers ===\n%{http_code} %{http_connect_time}s connect, %{time_starttransfer}s transfer\n" \
        -D - "$url" 2>&1 | head -20
}

check_redirect() {
    local url="$1"
    
    echo "=== Following Redirects ==="
    curl -s -w "Status: %{http_code}\nFinal URL: %{redirect_url}\n" \
        -L "$url"
}

test_ssl_certificate() {
    local url="$1"
    
    echo "=== SSL Certificate Check ==="
    curl -s -I --cacert /dev/null "$url" 2>&1 | grep -E "SSL|certificate" || curl -s -I "$url" | head -10
}

# Usage
analyze_response "https://httpbin.org/get"
