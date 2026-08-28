# Authentication Rules

**Priority: Critical**

## Overview

ClearNode authentication uses EIP-712 structured data signatures with a challenge-response flow.

## Authentication Flow

```
Client                              ClearNode
  │                                     │
  │──── auth_request ──────────────────▶│
  │                                     │
  │◀─── auth_challenge (nonce) ─────────│
  │                                     │
  │──── auth_verify (EIP-712 sig) ─────▶│
  │                                     │
  │◀─── auth_success (JWT token) ───────│
  │                                     │
```

## Rules

### AUTH-01: Use SDK Helper Functions

```javascript
// ✅ GOOD - Use SDK helpers
import {
  createAuthRequestMessage,
  createAuthVerifyMessage,
  createEIP712AuthMessageSigner,
} from '@erc7824/nitrolite';

const authRequest = await createAuthRequestMessage({
  address: walletAddress,
  session_key: signerAddress,
  application: 'YourApp',
  expires_at: (Math.floor(Date.now() / 1000) + 3600).toString(),
  scope: 'console',
  allowances: [],
});

// ❌ BAD - Manual message construction
const authRequest = JSON.stringify({
  req: [1, 'auth_request', [...], Date.now()]
});
```

### AUTH-02: Set Appropriate Expiration

```javascript
// ✅ GOOD - Reasonable expiration (1 hour)
const expires_at = (Math.floor(Date.now() / 1000) + 3600).toString();

// ❌ BAD - Too short (may expire during use)
const expires_at = (Math.floor(Date.now() / 1000) + 60).toString();

// ❌ BAD - Too long (security risk)
const expires_at = (Math.floor(Date.now() / 1000) + 86400 * 30).toString();
```

### AUTH-03: Store and Reuse JWT Tokens

Store JWT tokens for reconnection to avoid re-authenticating. See [SEC-07](05-security.md#sec-07-secure-token-storage) for secure storage patterns.

```javascript
// ✅ GOOD - Store JWT for reconnection (use sessionStorage for session-scoped tokens)
ws.onmessage = async (event) => {
  const message = parseRPCResponse(event.data);
  
  if (message.method === RPCMethod.AuthVerify && message.params.success) {
    // Store JWT token (sessionStorage clears on tab close)
    sessionStorage.setItem('clearnode_jwt', message.params.jwtToken);
  }
};

// Reconnect with stored JWT
const jwtToken = sessionStorage.getItem('clearnode_jwt');
if (jwtToken) {
  const authMsg = await createAuthVerifyMessageWithJWT(jwtToken);
  ws.send(authMsg);
}
```

> **Security Note**: For production applications with higher security requirements, encrypt tokens before storage. See [SEC-07](05-security.md#sec-07-secure-token-storage) for the `SecureStorage` pattern.

### AUTH-04: Use Session Keys (Not Main Wallet)

```javascript
// ✅ GOOD - Generate session key for signing
const sessionKey = ethers.Wallet.createRandom();
const authRequest = await createAuthRequestMessage({
  address: mainWalletAddress,      // Main wallet
  session_key: sessionKey.address, // Temporary session key
  // ...
});

// ❌ BAD - Using main wallet directly
const authRequest = await createAuthRequestMessage({
  address: mainWalletAddress,
  session_key: mainWalletAddress, // Same as main wallet!
  // ...
});
```

### AUTH-05: Handle Auth Failures Gracefully

```javascript
// ✅ GOOD
ws.onmessage = async (event) => {
  const message = parseRPCResponse(event.data);
  
  switch (message.method) {
    case RPCMethod.AuthVerify:
      if (!message.params.success) {
        console.error('Authentication failed');
        this.emit('auth_failed', message.params.error);
        return;
      }
      this.isAuthenticated = true;
      this.emit('authenticated');
      break;
      
    case RPCMethod.Error:
      console.error('Auth error:', message.params.error);
      this.handleAuthError(message.params);
      break;
  }
};
```

### AUTH-06: Use EIP-712 Domain Correctly

```javascript
// ✅ GOOD - Proper EIP-712 structure
const eip712MessageSigner = createEIP712AuthMessageSigner(
  walletClient,
  {
    scope: 'console',
    application: 'YourAppDomain',
    participant: walletAddress,
    expires_at: expiresAt,
    allowances: [],
  },
  {
    name: 'YourAppDomain', // Must match application
  }
);
```

## EIP-712 Message Format

```javascript
{
  types: {
    EIP712Domain: [{ name: 'name', type: 'string' }],
    Policy: [
      { name: 'challenge', type: 'string' },
      { name: 'scope', type: 'string' },
      { name: 'wallet', type: 'address' },
      { name: 'session_key', type: 'address' },
      { name: 'expires_at', type: 'uint64' },
      { name: 'allowances', type: 'Allowance[]' },
    ],
    Allowance: [
      { name: 'asset', type: 'string' },
      { name: 'amount', type: 'string' },
    ],
  },
  domain: { name: 'Your App Domain' },
  primaryType: 'Policy',
  message: {
    challenge: 'RandomChallengeString',
    scope: 'console',
    wallet: '0xWalletAddress',
    session_key: '0xSessionKeyAddress',
    expires_at: 1762417301,
    allowances: [],
  },
}
```

## Allowances Configuration (v0.5.x+)

Session keys now support application-scoped permissions:

```javascript
const allowances = [
  { asset: 'usdc', amount: '1000000' }, // 1 USDC limit
  { asset: 'eth', amount: '100000000000000000' }, // 0.1 ETH limit
];
```
