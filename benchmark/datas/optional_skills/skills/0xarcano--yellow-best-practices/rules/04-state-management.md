# State Management Rules

**Priority: High**

## Overview

State management in Nitrolite involves tracking channel states, off-chain balances, and application session states.

## Rules

### STATE-01: Use SDK Helper for Balance Queries

```javascript
// ✅ GOOD - Use SDK helper
import { createGetLedgerBalancesMessage } from '@erc7824/nitrolite';

const message = await createGetLedgerBalancesMessage(
  messageSigner,
  participantAddress
);
ws.send(message);

// ❌ BAD - Manual construction
const request = {
  req: [1, 'get_ledger_balances', [{ participant: address }], Date.now()]
};
```

### STATE-02: Sign Plain JSON (Not EIP-191)

```javascript
// ✅ GOOD - Sign raw message bytes
const messageSigner = async (payload) => {
  const wallet = new ethers.Wallet(privateKey);
  const messageBytes = ethers.utils.arrayify(
    ethers.utils.id(JSON.stringify(payload))
  );
  const flatSignature = await wallet._signingKey().signDigest(messageBytes);
  return ethers.utils.joinSignature(flatSignature);
};

// ❌ BAD - Using signMessage (adds EIP-191 prefix)
const signature = await wallet.signMessage(JSON.stringify(payload));
```

### STATE-03: Implement Balance Polling

```javascript
// ✅ GOOD - Regular balance monitoring
function startBalanceMonitoring(intervalMs = 30000) {
  // Check immediately
  getLedgerBalances().then(displayBalances);
  
  // Set up interval
  const intervalId = setInterval(() => {
    getLedgerBalances()
      .then(displayBalances)
      .catch(err => console.error('Balance check failed:', err));
  }, intervalMs);
  
  return () => clearInterval(intervalId);
}
```

### STATE-04: Handle Balance Response Format

```javascript
// Response format
{
  res: [1, 'get_ledger_balances', [[
    { asset: 'usdc', amount: '100.0' },
    { asset: 'eth', amount: '0.5' }
  ]], 1619123456789],
  sig: ['0xabcd1234...']
}

// ✅ GOOD - Parse correctly
const handleBalanceResponse = (message) => {
  if (message.method === RPCMethod.GetLedgerBalances) {
    const balances = message.params;
    
    if (balances.length > 0) {
      balances.forEach(balance => {
        console.log(`${balance.asset.toUpperCase()}: ${balance.amount}`);
      });
    }
  }
};
```

### STATE-05: Track Request-Response Mapping

```javascript
// ✅ GOOD - Map requests to responses
class ClearNodeConnection {
  constructor() {
    this.requestMap = new Map();
  }
  
  async sendRequest(method, params) {
    const { request, requestId } = await this.createSignedRequest(method, params);
    
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.requestMap.delete(requestId);
        reject(new Error(`Request timeout for ${method}`));
      }, 30000);
      
      this.requestMap.set(requestId, { resolve, reject, timeout });
      this.ws.send(JSON.stringify(request));
    });
  }
  
  handleMessage(event) {
    const message = JSON.parse(event.data);
    const requestId = message.res?.[0];
    
    const handler = this.requestMap.get(requestId);
    if (handler) {
      clearTimeout(handler.timeout);
      handler.resolve(message);
      this.requestMap.delete(requestId);
    }
  }
}
```

### STATE-06: Use generateRequestId and getCurrentTimestamp

```javascript
// ✅ GOOD - Use SDK utilities
import { generateRequestId, getCurrentTimestamp } from '@erc7824/nitrolite';

const requestId = generateRequestId();
const timestamp = getCurrentTimestamp();

const requestData = [requestId, method, params, timestamp];
```

## Channel Information

### Getting Channel List

```javascript
import { createGetChannelsMessage } from '@erc7824/nitrolite';

const message = await createGetChannelsMessage(
  messageSigner,
  participantAddress
);
ws.send(message);
```

### Channel Response Format

```javascript
{
  res: [1, 'get_channels', [[
    {
      channel_id: '0xfedcba9876543210...',
      participant: '0x1234567890abcdef...',
      status: 'open',  // open, closed, settling
      token: '0xeeee567890abcdef...',
      amount: '100000',
      chain_id: 137,
      adjudicator: '0xAdjudicatorContract...',
      challenge: 86400,
      nonce: 1,
      version: 2,
      created_at: '2023-05-01T12:00:00Z',
      updated_at: '2023-05-01T12:30:00Z'
    }
  ]], 1619123456789],
  sig: ['0xabcd1234...']
}
```

## State Channel Lifecycle

```
VOID → INITIAL → ACTIVE → DISPUTE → FINAL
  │       │         │         │        │
  │       │         │         │        └── Channel closed
  │       │         │         └── Challenge period
  │       │         └── Normal operations
  │       └── Channel created, awaiting funding
  └── No channel exists
```

## Unified Balance (Chain Abstraction)

Users have a unified balance across all supported chains:

```javascript
// Example: User deposited on multiple chains
// Polygon: 50 USDC
// Base: 50 USDC
// Unified balance: 100 USDC

// Can withdraw on any supported chain
await withdraw({
  chainId: 137,  // Polygon
  amount: '100000000',  // Full balance
  token: 'usdc'
});
```
