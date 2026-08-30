# cURL HTTP Reference

## Basic Requests

```bash
# GET request
curl https://api.example.com/users

# POST with JSON data
curl -X POST https://api.example.com/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John","email":"john@example.com"}'

# PUT request
curl -X PUT https://api.example.com/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane"}'

# DELETE request
curl -X DELETE https://api.example.com/users/1
```

## Headers & Authentication

```bash
# Add custom header
curl -H "Authorization: Bearer TOKEN" \
  https://api.example.com/users

# Multiple headers
curl -H "Authorization: Bearer TOKEN" \
  -H "X-Custom-Header: value" \
  https://api.example.com/users

# Basic auth
curl -u username:password https://api.example.com/users

# API key
curl -H "X-API-Key: your-api-key" \
  https://api.example.com/users
```

## Response Analysis

```bash
# Show response headers
curl -i https://api.example.com/users  # Headers + body
curl -I https://api.example.com/users  # Headers only

# Show headers with body
curl -D - https://api.example.com/users

# Follow redirects
curl -L https://api.example.com/users

# Verbose output
curl -v https://api.example.com/users
```

## Debugging

```bash
# Show timing info
curl -w "Time: %{time_total}s\n" https://api.example.com/users

# Save request/response
curl -D response_headers.txt -o response_body.txt \
  https://api.example.com/users

# Dry run (don't execute)
curl --trace-ascii debug.txt https://api.example.com/users
```

## File Uploads

```bash
# Upload file
curl -F "file=@/path/to/file.txt" \
  https://api.example.com/upload

# Upload with form data
curl -F "name=John" \
  -F "file=@/path/to/file.txt" \
  https://api.example.com/upload
```

## Performance

```bash
# Compress response
curl --compressed https://api.example.com/users

# Limit speed
curl --limit-rate 1000B https://api.example.com/users

# Max time
curl --max-time 10 https://api.example.com/users
```
