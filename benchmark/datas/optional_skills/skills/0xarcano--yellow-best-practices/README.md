# Yellow Best Practices

Yellow Network and Nitrolite (ERC-7824) development best practices for building state channel applications.

## Overview

This skill provides comprehensive guidelines for building high-performance decentralized applications using:

- **Yellow Network**: A decentralized clearing and settlement network
- **Nitrolite SDK**: The official SDK for ERC-7824 state channel applications
- **ClearNode**: Message broker for off-chain communication

## When to Use

Use this skill when:

- Building applications with Yellow Network SDK (`@erc7824/nitrolite`)
- Implementing state channels for high-frequency transactions
- Working with ClearNode connections and authentication
- Managing off-chain balances and transactions
- Creating and managing application sessions
- Implementing chain abstraction features

## Categories

| Category | Priority | Description |
|----------|----------|-------------|
| [Connection](rules/01-connection.md) | Critical | ClearNode WebSocket connection patterns |
| [Authentication](rules/02-authentication.md) | Critical | EIP-712 authentication flow |
| [App Sessions](rules/03-app-sessions.md) | High | Application session lifecycle |
| [State Management](rules/04-state-management.md) | High | Balance and state handling |
| [Security](rules/05-security.md) | Critical | Security best practices |
| [Error Handling](rules/06-error-handling.md) | Medium | Error recovery patterns |

## Quick Start

```bash
npm install @erc7824/nitrolite
```

```javascript
import {
  createAuthRequestMessage,
  createAuthVerifyMessage,
  createAppSessionMessage,
  parseRPCResponse,
} from '@erc7824/nitrolite';

// Connect to ClearNode
const ws = new WebSocket('wss://clearnet.yellow.com/ws');

// Authenticate
const authRequest = await createAuthRequestMessage({
  address: walletAddress,
  session_key: signerAddress,
  application: 'YourApp',
  expires_at: (Math.floor(Date.now() / 1000) + 3600).toString(),
  scope: 'console',
  allowances: [],
});

ws.send(authRequest);
```

## Key Concepts

### State Channels

State channels allow off-chain transactions with on-chain settlement:

```
┌─────────┐    Off-chain state    ┌─────────┐
│  Alice  │◄────────────────────►│   Bob   │
└────┬────┘       updates         └────┬────┘
     │                                  │
     └──────────┬───────────────────────┘
                │
         ┌──────▼──────┐
         │ Blockchain  │
         │ (Settlement)│
         └─────────────┘
```

### Chain Abstraction

Yellow Network provides unified balances across multiple chains:

- Deposit on Polygon
- Withdraw on Base
- Single unified balance

### Application Sessions

Isolated environments for specific interactions:

1. Create session with allocations
2. Execute off-chain transactions
3. Close session with final state

## Documentation

- [Yellow Network Docs](https://docs.yellow.org/)
- [ERC-7824 Documentation](https://erc7824.org/)
- [Nitrolite GitHub](https://github.com/erc7824/nitrolite)
- [LLM Documentation](https://erc7824.org/llms-full.txt)

## License

MIT
