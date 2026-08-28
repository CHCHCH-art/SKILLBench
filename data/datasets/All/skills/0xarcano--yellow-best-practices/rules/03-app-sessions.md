# Application Session Rules

**Priority: High**

## Overview

Application sessions are isolated environments for specific interactions between participants. They define rules for off-chain transactions and fund allocations.

## Session Lifecycle

```
Create Session → Active → Transactions → Close Session
     │                                        │
     └──── allocations defined ───────────────┘
```

## Rules

### SESSION-01: Define Clear App Definition

```javascript
// ✅ GOOD - All required fields
const appDefinition = {
  protocol: 'nitroliterpc',           // Protocol identifier
  participants: [participantA, participantB],
  weights: [100, 0],                  // Weight distribution
  quorum: 100,                        // Required consensus
  challenge: 0,                       // Challenge period (seconds)
  nonce: Date.now(),                  // Unique identifier
};

// ❌ BAD - Missing fields
const appDefinition = {
  participants: [participantA, participantB],
  // Missing protocol, weights, quorum, etc.
};
```

### SESSION-02: Use Asset Identifiers (Not Token Addresses)

```javascript
// ✅ GOOD - Use asset identifiers
const allocations = [
  { participant: participantA, asset: 'usdc', amount: '1000000' },
  { participant: participantB, asset: 'usdc', amount: '0' },
];

// ❌ BAD - Using token addresses (deprecated pattern)
const allocations = [
  { participant: participantA, token: '0xA0b8...', amount: '1000000' },
];
```

### SESSION-03: Store Session ID

```javascript
// ✅ GOOD - Store session ID for later use
const response = await sendRequest(signedMessage);

if (response.app_session_id) {
  localStorage.setItem('app_session_id', response.app_session_id);
  this.currentSessionId = response.app_session_id;
}

// Later, for closing
const sessionId = localStorage.getItem('app_session_id');
await closeSession(sessionId);
```

### SESSION-04: Handle Session Creation Response

```javascript
// ✅ GOOD - Parse response correctly
const handleMessage = (event) => {
  const message = JSON.parse(event.data);
  
  if (message.res && message.res[1] === 'create_app_session') {
    const result = message.res[2]?.[0];
    
    if (result?.app_session_id) {
      console.log('Session created:', result.app_session_id);
      console.log('Status:', result.status); // "open"
    }
  }
  
  if (message.err) {
    console.error('Error:', message.err[1], message.err[2]);
  }
};
```

### SESSION-05: Always Close Sessions Properly

```javascript
// ✅ GOOD - Proper session closure
import { createCloseAppSessionMessage } from '@erc7824/nitrolite';

async function closeSession(appId, finalAllocations) {
  const closeRequest = {
    app_session_id: appId,
    allocations: [
      { participant: participantA, asset: 'usdc', amount: '200000' },
      { participant: participantB, asset: 'usdc', amount: '800000' },
    ],
  };
  
  const message = await createCloseAppSessionMessage(signer, [closeRequest]);
  await sendRequest(message);
  
  // Clean up
  localStorage.removeItem('app_session_id');
}

// ❌ BAD - Abandoning session without closing
// Session left open indefinitely
```

### SESSION-06: Set Appropriate Timeouts

```javascript
// ✅ GOOD - Timeout for session operations
const createSession = (params) => {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      ws.removeEventListener('message', handleMessage);
      reject(new Error('Session creation timeout'));
    }, 10000);
    
    const handleMessage = (event) => {
      // Handle response...
      clearTimeout(timeout);
      resolve(result);
    };
    
    ws.addEventListener('message', handleMessage);
    ws.send(signedMessage);
  });
};
```

## Weight Distribution Patterns

| Pattern | Weights | Use Case |
|---------|---------|----------|
| User-controlled | `[100, 0]` | User has full control |
| Equal | `[50, 50]` | Both parties must agree |
| Server-referee | `[0, 0, 100]` | Server mediates disputes |
| Multi-party | `[30, 30, 40]` | Weighted consensus |

## Application Session Use Cases

### Payment Application

```javascript
const allocations = [
  { participant: payer, asset: 'usdc', amount: '1000000' },
  { participant: payee, asset: 'usdc', amount: '0' },
];

// After payment
const finalAllocations = [
  { participant: payer, asset: 'usdc', amount: '0' },
  { participant: payee, asset: 'usdc', amount: '1000000' },
];
```

### Game with Server Referee

```javascript
const appDefinition = {
  protocol: 'game_v1',
  participants: [player1, player2, server],
  weights: [0, 0, 100], // Server decides outcomes
  quorum: 100,
  challenge: 3600, // 1 hour challenge period
  nonce: Date.now(),
};
```

## Response Format

```javascript
// Create session response
{
  res: [
    requestId,
    'create_app_session',
    [{
      app_session_id: '0x0ac588b2...',
      status: 'open'
    }],
    timestamp
  ],
  sig: ['0xSignature']
}

// Close session response
{
  res: [
    requestId,
    'close_app_session',
    [{
      app_session_id: '0x0ac588b2...',
      status: 'closed'
    }],
    timestamp
  ],
  sig: ['0xSignature']
}
```
