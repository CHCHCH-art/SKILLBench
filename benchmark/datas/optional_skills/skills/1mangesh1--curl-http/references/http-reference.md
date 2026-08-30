# HTTP Status Codes & Methods

## HTTP Methods

| Method | Purpose | Safe | Idempotent |
|--------|---------|------|-----------|
| GET | Retrieve resource | Yes | Yes |
| POST | Create resource | No | No |
| PUT | Replace resource | No | Yes |
| PATCH | Partial update | No | No |
| DELETE | Remove resource | No | Yes |
| HEAD | Like GET, no body | Yes | Yes |

## Status Codes

### 2xx Success
- `200 OK` - Request succeeded
- `201 Created` - Resource created
- `204 No Content` - Success, no body

### 3xx Redirection
- `301 Moved Permanently` - Resource moved
- `302 Found` - Temporary redirect
- `304 Not Modified` - Cache is fresh

### 4xx Client Error
- `400 Bad Request` - Invalid request
- `401 Unauthorized` - Need authentication
- `403 Forbidden` - Authenticated but no access
- `404 Not Found` - Resource doesn't exist
- `429 Too Many Requests` - Rate limited

### 5xx Server Error
- `500 Internal Server Error` - Server problem
- `503 Service Unavailable` - Server down
- `504 Gateway Timeout` - Slow backend

## Content Negotiation

```bash
# Accept JSON
curl -H "Accept: application/json" https://api.example.com/users

# Accept XML
curl -H "Accept: application/xml" https://api.example.com/users

# Request JSON, send JSON
curl -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST https://api.example.com/users
```

## Common Patterns

### Error Response
```json
{
  "error": "Invalid request",
  "message": "Email is required",
  "code": "VALIDATION_ERROR"
}
```

### Pagination
```bash
curl "https://api.example.com/users?page=1&limit=20"
```

### Filtering
```bash
curl "https://api.example.com/users?status=active&role=admin"
```

### Sorting
```bash
curl "https://api.example.com/users?sort=-created_at&sort=name"
```
