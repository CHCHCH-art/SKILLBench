---
name: api-authentication
description: API authentication patterns including JWT, OAuth 2.0, API keys, and session-based auth. Covers token generation, validation, refresh strategies, security best practices, and when to use each pattern. Use when implementing API authentication, choosing auth strategy, securing endpoints, or debugging auth issues. Prevents common vulnerabilities like token theft, replay attacks, and insecure storage.
---

# API Authentication Patterns

Comprehensive guide to implementing secure API authentication including JWT, OAuth 2.0, API keys, and session-based patterns. Covers when to use each approach, security best practices, and common vulnerabilities to avoid.

---

## Quick Reference

**When to use this skill:**
- Implementing API authentication
- Choosing between auth strategies (JWT vs OAuth vs sessions)
- Securing API endpoints
- Implementing token refresh logic
- Debugging authentication issues
- Preventing auth vulnerabilities

**Common triggers:**
- "How should I implement authentication"
- "JWT vs OAuth vs API keys"
- "How to secure this API"
- "Implement refresh tokens"
- "Store authentication tokens securely"
- "Fix authentication vulnerability"

**Prevents vulnerabilities:**
- Token theft and replay attacks
- Insecure token storage
- Missing token expiration
- Weak password hashing
- CSRF attacks

---

## Part 1: Authentication Strategy Decision Matrix

### When to Use Each Pattern

| Pattern | Best For | Pros | Cons |
|---------|----------|------|------|
| **JWT** | Stateless APIs, microservices, mobile apps | Stateless, scalable, works across domains | Tokens can't be revoked easily, larger payload |
| **OAuth 2.0** | Third-party access, social login, delegation | Industry standard, fine-grained permissions | Complex to implement, requires authorization server |
| **API Keys** | Server-to-server, public APIs, rate limiting | Simple, great for service accounts | Not for users, can't be scoped easily |
| **Sessions** | Traditional web apps, SSR, same-domain | Revocable, server-controlled, secure | Requires server state, doesn't scale horizontally easily |

### Decision Tree

```
START: What type of client?

├─ Mobile app or SPA?
│  └─ Use JWT (stateless, works across domains)
│
├─ Third-party integration?
│  └─ Use OAuth 2.0 (delegation, scoped permissions)
│
├─ Service-to-service?
│  └─ Use API Keys (simple, rate-limitable)
│
└─ Traditional web app (same domain)?
   └─ Use Sessions (revocable, server-controlled)
```

---

## Part 2: JWT (JSON Web Tokens)

### JWT Structure

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c

[HEADER].[PAYLOAD].[SIGNATURE]
```

**Header** (algorithm and type):
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

**Payload** (claims):
```json
{
  "sub": "1234567890",    // Subject (user ID)
  "name": "John Doe",     // Custom claim
  "iat": 1516239022,      // Issued at
  "exp": 1516242622       // Expires at (required!)
}
```

**Signature** (verification):
```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```

### JWT Implementation (Python)

```python
import jwt
import datetime
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

SECRET_KEY = "your-256-bit-secret"  # Must be strong, from environment
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 7

security = HTTPBearer()

def create_access_token(user_id: int) -> str:
    """Create short-lived access token."""
    expires = datetime.datetime.utcnow() + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "exp": expires,
        "iat": datetime.datetime.utcnow(),
        "type": "access"
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(user_id: int) -> str:
    """Create long-lived refresh token."""
    expires = datetime.datetime.utcnow() + datetime.timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "exp": expires,
        "iat": datetime.datetime.utcnow(),
        "type": "refresh"
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """Verify and decode JWT token."""
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

# Login endpoint
@app.post("/login")
async def login(username: str, password: str):
    user = authenticate_user(username, password)  # Your auth logic
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

# Protected endpoint
@app.get("/protected")
async def protected_route(payload: dict = Depends(verify_token)):
    user_id = payload["sub"]
    return {"message": f"Hello user {user_id}"}

# Refresh token endpoint
@app.post("/refresh")
async def refresh(refresh_token: str):
    try:
        payload = jwt.decode(refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type")

        # Generate new access token
        user_id = int(payload["sub"])
        new_access_token = create_access_token(user_id)

        return {"access_token": new_access_token, "token_type": "bearer"}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Refresh token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
```

### JWT Security Best Practices

**✅ Do:**
- Use strong secret keys (256-bit minimum)
- Always set expiration (`exp` claim)
- Use short-lived access tokens (15 minutes)
- Use separate refresh tokens (7 days)
- Store secret in environment variables
- Use HTTPS only
- Validate signature on every request
- Check token type (`access` vs `refresh`)

**❌ Don't:**
- Store sensitive data in payload (it's base64, not encrypted!)
- Use symmetric signing (HS256) for public APIs (use RS256)
- Store tokens in localStorage (XSS vulnerability)
- Skip expiration validation
- Use same token for access and refresh
- Hard-code secrets

### Token Storage (Client-Side)

**❌ Bad** (localStorage - vulnerable to XSS):
```javascript
localStorage.setItem('token', token);  // XSS can steal this!
```

**✅ Good** (httpOnly cookie):
```python
# Server sets httpOnly cookie
response.set_cookie(
    key="access_token",
    value=access_token,
    httponly=True,  # Not accessible via JavaScript
    secure=True,    # HTTPS only
    samesite="lax", # CSRF protection
    max_age=900     # 15 minutes
)
```

**✅ Also Good** (memory only for SPAs):
```javascript
// Store in memory (lost on refresh, but more secure)
let accessToken = null;

async function login(username, password) {
  const response = await fetch('/login', {
    method: 'POST',
    body: JSON.stringify({ username, password })
  });
  const data = await response.json();
  accessToken = data.access_token;  // Store in memory
}
```

---

## Part 3: OAuth 2.0

### OAuth 2.0 Flows

**Authorization Code Flow** (most common, for web apps):
```
1. Client → Authorization Server: "User wants to log in"
2. Authorization Server → User: Login page
3. User → Authorization Server: Credentials
4. Authorization Server → Client: Authorization code
5. Client → Authorization Server: Exchange code for access token
6. Authorization Server → Client: Access token + refresh token
```

**Client Credentials Flow** (for service-to-service):
```
1. Service → Authorization Server: Client ID + Secret
2. Authorization Server → Service: Access token
```

### OAuth 2.0 Implementation (Authorization Code Flow)

```python
from fastapi import FastAPI, HTTPException
from authlib.integrations.starlette_client import OAuth
import os

app = FastAPI()

oauth = OAuth()
oauth.register(
    name='google',
    client_id=os.getenv('GOOGLE_CLIENT_ID'),
    client_secret=os.getenv('GOOGLE_CLIENT_SECRET'),
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'}
)

@app.get('/login/google')
async def login_google(request: Request):
    redirect_uri = request.url_for('auth_google')
    return await oauth.google.authorize_redirect(request, redirect_uri)

@app.get('/auth/google')
async def auth_google(request: Request):
    try:
        token = await oauth.google.authorize_access_token(request)
        user_info = token.get('userinfo')

        # Create or update user in your database
        user = get_or_create_user(
            email=user_info['email'],
            name=user_info['name']
        )

        # Create your own JWT for subsequent requests
        access_token = create_access_token(user.id)

        return {"access_token": access_token, "token_type": "bearer"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
```

### OAuth 2.0 Scopes

```python
# Define scopes for your API
SCOPES = {
    "read:posts": "Read posts",
    "write:posts": "Create and edit posts",
    "delete:posts": "Delete posts",
    "read:profile": "Read user profile",
    "write:profile": "Update user profile"
}

# Include scopes in JWT
def create_access_token(user_id: int, scopes: list[str]) -> str:
    payload = {
        "sub": str(user_id),
        "exp": datetime.datetime.utcnow() + datetime.timedelta(minutes=15),
        "scopes": scopes  # Add scopes to token
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

# Check scopes in protected endpoint
def require_scopes(required_scopes: list[str]):
    def decorator(func):
        async def wrapper(payload: dict = Depends(verify_token)):
            token_scopes = payload.get("scopes", [])
            if not all(scope in token_scopes for scope in required_scopes):
                raise HTTPException(status_code=403, detail="Insufficient permissions")
            return await func(payload)
        return wrapper
    return decorator

@app.delete("/posts/{post_id}")
@require_scopes(["delete:posts"])
async def delete_post(post_id: int, payload: dict = Depends(verify_token)):
    # User has delete:posts scope
    pass
```

---

## Part 4: API Keys

### API Key Implementation

```python
import secrets
import hashlib
from datetime import datetime

# Generate API key
def generate_api_key() -> tuple[str, str]:
    """Generate API key and return (key, hashed_key)."""
    # Generate random 32-byte key
    api_key = secrets.token_urlsafe(32)

    # Hash for storage (never store plain key!)
    hashed_key = hashlib.sha256(api_key.encode()).hexdigest()

    return api_key, hashed_key

# Store in database
def create_api_key(user_id: int, name: str) -> str:
    api_key, hashed_key = generate_api_key()

    db.execute("""
        INSERT INTO api_keys (user_id, name, key_hash, created_at)
        VALUES (?, ?, ?, ?)
    """, user_id, name, hashed_key, datetime.utcnow())

    # Return plain key to user (only time they see it!)
    return api_key

# Verify API key
def verify_api_key(api_key: str) -> dict:
    """Verify API key and return user info."""
    hashed_key = hashlib.sha256(api_key.encode()).hexdigest()

    result = db.execute("""
        SELECT user_id, name, created_at, last_used_at
        FROM api_keys
        WHERE key_hash = ? AND revoked_at IS NULL
    """, hashed_key).fetchone()

    if not result:
        raise HTTPException(status_code=401, detail="Invalid API key")

    # Update last used timestamp
    db.execute("""
        UPDATE api_keys
        SET last_used_at = ?
        WHERE key_hash = ?
    """, datetime.utcnow(), hashed_key)

    return {"user_id": result[0], "key_name": result[1]}

# Middleware
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key")

@app.get("/api/data")
async def get_data(api_key: str = Security(api_key_header)):
    user_info = verify_api_key(api_key)
    return {"data": "protected data", "user_id": user_info["user_id"]}
```

### API Key Best Practices

**✅ Do:**
- Hash keys before storing (use SHA-256 minimum)
- Generate cryptographically secure keys (`secrets` module)
- Allow users to name keys ("Production Server", "CI/CD")
- Track last used timestamp
- Allow key revocation
- Rate limit by API key
- Log API key usage

**❌ Don't:**
- Store plain text keys
- Use predictable key generation
- Expose keys in URLs (use headers)
- Share keys across environments

### API Key Revocation

```python
@app.delete("/api-keys/{key_id}")
async def revoke_api_key(key_id: int, current_user: dict = Depends(get_current_user)):
    db.execute("""
        UPDATE api_keys
        SET revoked_at = ?
        WHERE id = ? AND user_id = ?
    """, datetime.utcnow(), key_id, current_user["id"])

    return {"message": "API key revoked"}
```

---

## Part 5: Session-Based Authentication

### Session Implementation

```python
from fastapi import FastAPI, Cookie, Response
import redis
import secrets
import json

app = FastAPI()
redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)

def create_session(user_id: int) -> str:
    """Create session and return session ID."""
    session_id = secrets.token_urlsafe(32)

    session_data = {
        "user_id": user_id,
        "created_at": datetime.utcnow().isoformat()
    }

    # Store in Redis with 24-hour expiry
    redis_client.setex(
        f"session:{session_id}",
        86400,  # 24 hours
        json.dumps(session_data)
    )

    return session_id

def verify_session(session_id: str) -> dict:
    """Verify session and return user data."""
    session_data = redis_client.get(f"session:{session_id}")

    if not session_data:
        raise HTTPException(status_code=401, detail="Session expired")

    return json.loads(session_data)

@app.post("/login")
async def login(username: str, password: str, response: Response):
    user = authenticate_user(username, password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Create session
    session_id = create_session(user.id)

    # Set httpOnly cookie
    response.set_cookie(
        key="session_id",
        value=session_id,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=86400  # 24 hours
    )

    return {"message": "Logged in successfully"}

@app.get("/protected")
async def protected_route(session_id: str = Cookie(None)):
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")

    session_data = verify_session(session_id)
    user_id = session_data["user_id"]

    return {"message": f"Hello user {user_id}"}

@app.post("/logout")
async def logout(session_id: str = Cookie(None), response: Response):
    if session_id:
        redis_client.delete(f"session:{session_id}")

    response.delete_cookie("session_id")
    return {"message": "Logged out successfully"}
```

---

## Part 6: Password Security

### Password Hashing (Never Store Plain Text!)

```python
import bcrypt

def hash_password(password: str) -> str:
    """Hash password with bcrypt."""
    salt = bcrypt.gensalt(rounds=12)  # 12 rounds is good balance
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    """Verify password against hash."""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

# When creating user
@app.post("/register")
async def register(username: str, password: str):
    # Validate password strength
    if len(password) < 12:
        raise HTTPException(status_code=400, detail="Password must be at least 12 characters")

    # Hash password
    hashed_password = hash_password(password)

    # Store hashed password (NEVER plain text!)
    db.execute("""
        INSERT INTO users (username, password_hash)
        VALUES (?, ?)
    """, username, hashed_password)

    return {"message": "User created"}

# When logging in
@app.post("/login")
async def login(username: str, password: str):
    user = db.execute("SELECT id, password_hash FROM users WHERE username = ?", username).fetchone()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Verify password
    if not verify_password(password, user[1]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Create token/session
    access_token = create_access_token(user[0])
    return {"access_token": access_token}
```

### Password Requirements

**Minimum requirements**:
- At least 12 characters (NIST recommendation)
- Mix of uppercase, lowercase, numbers, symbols
- Not in common password list
- Not similar to username

**Implementation**:
```python
import re

def validate_password(password: str, username: str) -> tuple[bool, str]:
    """Validate password strength."""
    if len(password) < 12:
        return False, "Password must be at least 12 characters"

    if not re.search(r"[a-z]", password):
        return False, "Password must contain lowercase letter"

    if not re.search(r"[A-Z]", password):
        return False, "Password must contain uppercase letter"

    if not re.search(r"\d", password):
        return False, "Password must contain number"

    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        return False, "Password must contain special character"

    if username.lower() in password.lower():
        return False, "Password cannot contain username"

    # Check against common passwords
    if is_common_password(password):
        return False, "Password is too common"

    return True, "Password is strong"
```

---

## Part 7: Common Vulnerabilities

### Vulnerability 1: Token Replay Attacks

**Problem**: Attacker intercepts token and reuses it

**✅ Solution**: Short expiration + refresh tokens
```python
# Access token: 15 minutes
# Refresh token: 7 days, single-use

def refresh_tokens(refresh_token: str):
    # Verify refresh token
    payload = jwt.decode(refresh_token, SECRET_KEY)

    # Check if already used (store used tokens in Redis)
    if redis_client.get(f"used:{refresh_token}"):
        raise HTTPException(status_code=401, detail="Token already used")

    # Mark as used
    redis_client.setex(f"used:{refresh_token}", 604800, "1")  # 7 days

    # Generate new tokens
    user_id = int(payload["sub"])
    new_access = create_access_token(user_id)
    new_refresh = create_refresh_token(user_id)

    return {"access_token": new_access, "refresh_token": new_refresh}
```

### Vulnerability 2: CSRF Attacks

**Problem**: Attacker tricks user into making authenticated request

**✅ Solution**: CSRF tokens + SameSite cookies
```python
from fastapi import Cookie, Header

def verify_csrf(
    csrf_token: str = Header(None, alias="X-CSRF-Token"),
    session_id: str = Cookie(None)
):
    """Verify CSRF token matches session."""
    if not csrf_token:
        raise HTTPException(status_code=403, detail="CSRF token missing")

    session_data = verify_session(session_id)
    stored_csrf = session_data.get("csrf_token")

    if csrf_token != stored_csrf:
        raise HTTPException(status_code=403, detail="Invalid CSRF token")

@app.post("/sensitive-action")
async def sensitive_action(
    csrf_check: None = Depends(verify_csrf)
):
    # Action protected from CSRF
    pass
```

### Vulnerability 3: Timing Attacks

**Problem**: Attacker uses response timing to guess credentials

**✅ Solution**: Constant-time comparison
```python
import hmac

def constant_time_compare(a: str, b: str) -> bool:
    """Compare strings in constant time (prevents timing attacks)."""
    return hmac.compare_digest(a, b)

# Use for password hash comparison
if not constant_time_compare(provided_hash, stored_hash):
    raise HTTPException(status_code=401)
```

---

## Part 8: Rate Limiting

```python
from fastapi import Request
import time

# In-memory rate limiter (use Redis for production)
rate_limits = {}

def rate_limit(max_requests: int, window_seconds: int):
    """Rate limit decorator."""
    def decorator(func):
        async def wrapper(request: Request, *args, **kwargs):
            client_ip = request.client.host
            key = f"{client_ip}:{func.__name__}"

            now = time.time()

            if key not in rate_limits:
                rate_limits[key] = []

            # Remove old requests outside window
            rate_limits[key] = [
                req_time for req_time in rate_limits[key]
                if now - req_time < window_seconds
            ]

            # Check if over limit
            if len(rate_limits[key]) >= max_requests:
                raise HTTPException(
                    status_code=429,
                    detail=f"Rate limit exceeded. Try again in {window_seconds} seconds."
                )

            # Add current request
            rate_limits[key].append(now)

            return await func(request, *args, **kwargs)
        return wrapper
    return decorator

@app.post("/login")
@rate_limit(max_requests=5, window_seconds=60)  # 5 login attempts per minute
async def login(request: Request, username: str, password: str):
    # Login logic
    pass
```

---

## Quick Security Checklist

**Token Security**:
- [ ] Always use HTTPS (never HTTP)
- [ ] Set token expiration (15 min for access, 7 days for refresh)
- [ ] Store secrets in environment variables
- [ ] Hash API keys before storing
- [ ] Use httpOnly cookies for tokens
- [ ] Never store sensitive data in JWT payload

**Password Security**:
- [ ] Use bcrypt or argon2 for hashing
- [ ] Enforce minimum 12 characters
- [ ] Never store plain text passwords
- [ ] Use constant-time comparison
- [ ] Implement rate limiting on login

**API Security**:
- [ ] Validate all inputs
- [ ] Implement rate limiting
- [ ] Use CORS restrictions
- [ ] Add CSRF protection for state-changing operations
- [ ] Log authentication events
- [ ] Monitor for suspicious patterns

---

## Resources

**JWT**:
- JWT.io: https://jwt.io/
- RFC 7519: https://tools.ietf.org/html/rfc7519

**OAuth 2.0**:
- OAuth 2.0 RFC: https://tools.ietf.org/html/rfc6749
- OAuth 2.0 Playground: https://www.oauth.com/playground/

**Security**:
- OWASP Auth Cheatsheet: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- NIST Password Guidelines: https://pages.nist.gov/800-63-3/

**Libraries**:
- PyJWT: https://pyjwt.readthedocs.io/
- Authlib: https://docs.authlib.org/
- Passlib: https://passlib.readthedocs.io/
