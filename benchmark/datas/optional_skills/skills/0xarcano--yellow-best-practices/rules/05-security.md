# Security Best Practices

**Priority: Critical**

## Overview

Security is paramount when dealing with state channels and cryptographic operations. These rules help protect user funds and prevent common vulnerabilities.

## Rules

### SEC-01: Never Expose Private Keys

```javascript
// ❌ EXTREMELY BAD - Hardcoded private key
const wallet = new ethers.Wallet('0x1234567890abcdef...');

// ❌ BAD - Private key in logs
console.log('Wallet:', privateKey);

// ✅ GOOD - Environment variables (server-side only)
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);

// ✅ BEST - Use secure key management
const wallet = await getWalletFromSecureStorage();
```

### SEC-02: Use Session Keys

```javascript
// ✅ GOOD - Generate temporary session keys
class SessionKeyManager {
  generateSessionKey() {
    const sessionKey = ethers.Wallet.createRandom();
    
    // Store securely with expiration
    this.storeSessionKey(sessionKey, {
      expiresAt: Date.now() + 3600000, // 1 hour
      scope: 'app_session',
    });
    
    return sessionKey;
  }
  
  rotateSessionKey() {
    // Invalidate old key
    this.invalidateCurrentKey();
    // Generate new key
    return this.generateSessionKey();
  }
}
```

### SEC-03: Always Use WSS (TLS)

```javascript
// ✅ GOOD - Secure WebSocket
const ws = new WebSocket('wss://clearnet.yellow.com/ws');

// ❌ BAD - Unencrypted connection
const ws = new WebSocket('ws://clearnet.yellow.com/ws');
```

### SEC-04: Verify Message Signatures

```javascript
// ✅ GOOD - Verify incoming signatures
import { verifySignature } from '@erc7824/nitrolite';

const handleMessage = (event) => {
  const message = JSON.parse(event.data);
  
  if (message.sig) {
    const isValid = verifySignature(message);
    if (!isValid) {
      console.error('Invalid signature, rejecting message');
      return;
    }
  }
  
  // Process verified message
  processMessage(message);
};
```

### SEC-05: Validate Channel States

```javascript
// ✅ GOOD - Validate state before processing
const validateState = (state) => {
  // Check participants
  if (!state.participants || state.participants.length < 2) {
    throw new Error('Invalid participants');
  }
  
  // Check allocations sum
  const total = state.allocations.reduce(
    (sum, a) => sum + BigInt(a.amount),
    BigInt(0)
  );
  
  if (total !== state.totalLocked) {
    throw new Error('Allocation mismatch');
  }
  
  // Check nonce is incrementing
  if (state.nonce <= this.lastKnownNonce) {
    throw new Error('Stale state');
  }
  
  return true;
};
```

### SEC-06: Implement Rate Limiting

```javascript
// ✅ GOOD - Rate limit requests
class RateLimiter {
  constructor(maxRequests = 100, windowMs = 60000) {
    this.requests = [];
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
  }
  
  canMakeRequest() {
    const now = Date.now();
    this.requests = this.requests.filter(t => t > now - this.windowMs);
    
    if (this.requests.length >= this.maxRequests) {
      return false;
    }
    
    this.requests.push(now);
    return true;
  }
}

// Usage
const rateLimiter = new RateLimiter();

const sendMessage = (message) => {
  if (!rateLimiter.canMakeRequest()) {
    throw new Error('Rate limit exceeded');
  }
  ws.send(message);
};
```

### SEC-07: Secure Token Storage

Choose storage based on your security requirements:

```javascript
// ✅ BASIC - sessionStorage for session-scoped tokens (clears on tab close)
// Suitable for most applications where JWT has short expiration
sessionStorage.setItem('clearnode_jwt', jwtToken);

// ✅ BETTER - Encrypt sensitive data at rest (for higher security requirements)
class SecureStorage {
  async storeJWT(token) {
    // Browser: Use httpOnly cookies when possible
    // Or encrypt before storing
    const encrypted = await this.encrypt(token);
    sessionStorage.setItem('clearnode_jwt', encrypted);
  }
  
  async getJWT() {
    const encrypted = sessionStorage.getItem('clearnode_jwt');
    if (!encrypted) return null;
    return await this.decrypt(encrypted);
  }
}

// ⚠️ CAUTION - localStorage persists across sessions
// Only use for non-sensitive data or when persistence is required
// Never store private keys in localStorage
localStorage.setItem('clearnode_jwt', jwtToken); // Less secure - persists indefinitely

// ❌ BAD - Never store private keys in browser storage
localStorage.setItem('private_key', privateKey);
```

**Storage Comparison:**

| Storage | Persistence | Security | Use Case |
|---------|-------------|----------|----------|
| `sessionStorage` | Tab close | Medium | JWT tokens (recommended) |
| `localStorage` | Permanent | Lower | Non-sensitive preferences |
| Encrypted storage | Configurable | Higher | Production with strict requirements |
| httpOnly cookies | Configurable | Highest | Server-rendered apps |

### SEC-08: Handle Sensitive Data in Memory

```javascript
// ✅ GOOD - Clear sensitive data when done
class WalletManager {
  async signMessage(payload) {
    const privateKey = await this.getPrivateKey();
    
    try {
      const signature = await this.sign(privateKey, payload);
      return signature;
    } finally {
      // Clear from memory (as much as possible in JS)
      privateKey = null;
    }
  }
}
```

### SEC-09: Implement Timeout for All Operations

```javascript
// ✅ GOOD - Timeout on all async operations
const withTimeout = (promise, ms, errorMessage) => {
  const timeout = new Promise((_, reject) => {
    setTimeout(() => reject(new Error(errorMessage)), ms);
  });
  return Promise.race([promise, timeout]);
};

// Usage
const response = await withTimeout(
  sendRequest(message),
  10000,
  'Request timeout'
);
```

### SEC-10: Don't Trust Client Input

```javascript
// ✅ GOOD - Validate all inputs
const createSession = async (params) => {
  // Validate participant addresses
  if (!ethers.utils.isAddress(params.participantA)) {
    throw new Error('Invalid participant A address');
  }
  
  // Validate amounts
  if (BigInt(params.amount) <= 0) {
    throw new Error('Invalid amount');
  }
  
  // Sanitize strings
  const protocol = params.protocol.replace(/[^a-z0-9_]/gi, '');
  
  // Proceed with validated data
  return await _createSession({ ...params, protocol });
};
```

## Security Checklist

- [ ] Using WSS for all connections
- [ ] Session keys instead of main wallet
- [ ] Private keys never logged or hardcoded
- [ ] All message signatures verified
- [ ] Rate limiting implemented
- [ ] Timeouts on all async operations
- [ ] Sensitive data cleared from memory
- [ ] Input validation on all user data
- [ ] JWT tokens stored securely
- [ ] Challenge period understood for disputes
