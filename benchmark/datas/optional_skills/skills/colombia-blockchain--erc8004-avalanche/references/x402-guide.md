# x402: Micropayment Protocol for ERC-8004 Agents

Complete implementation guide for the x402 payment protocol. x402 enables agents to charge for premium endpoints using USDC micropayments on Avalanche C-Chain.

---

## How x402 Works

```
┌──────────────────────────────────────────────────────────────────┐
│                     x402 PAYMENT FLOW                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CLIENT (Agent/User)              SERVER (Your Agent)            │
│  ─────────────────                ───────────────────            │
│                                                                  │
│  1. GET /api/premium ──────────▶  "What does this cost?"        │
│                                                                  │
│  2. ◀─── 402 Payment Required     Returns payment details:      │
│          {                         - amount (USDC)               │
│            amount: "10000",        - recipient address           │
│            asset: "0xUSDC...",     - network                    │
│            recipient: "0x...",     - facilitator URL             │
│            network: "avalanche"                                  │
│          }                                                       │
│                                                                  │
│  3. Client signs EIP-712          "I authorize this payment"     │
│     TransferWithAuthorization                                    │
│                                                                  │
│  4. POST /api/premium ─────────▶  Sends signed payment in       │
│     Header: X-PAYMENT: base64     X-PAYMENT header              │
│                                                                  │
│  5. Server verifies payment ────▶ Calls facilitator to verify   │
│     via facilitator                                              │
│                                                                  │
│  6. ◀─── 200 OK + Data           Payment verified, data served  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Server Side: Receiving x402 Payments

### 1. Define Payment Requirements

```typescript
// x402 Configuration
const X402_CONFIG = {
  // USDC contract address on Avalanche C-Chain
  asset: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",  // Mainnet USDC
  // asset: "0x5425890298aed601595a70AB815c96711a31Bc65", // Fuji USDC (testnet)

  // Your agent's wallet address (receives payments)
  recipient: "0xYOUR_WALLET_ADDRESS",

  // Network identifier
  network: "avalanche",  // or "avalanche-fuji" for testnet

  // Facilitator that verifies and executes payments
  facilitatorUrl: "https://facilitator.ultravioletadao.xyz",

  // Price in USDC micro-units (6 decimals)
  // 10000 = $0.01 USDC
  // 100000 = $0.10 USDC
  // 1000000 = $1.00 USDC
  prices: {
    "premium-analysis": 10000,   // $0.01
    "deep-research": 100000,     // $0.10
  },
};
```

### 2. Implement the 402 Response

```typescript
import { Hono } from "hono";

const app = new Hono();

// Free endpoint - no payment required
app.get("/api/price", async (c) => {
  return c.json({ avax: 25.50, source: "coingecko" });
});

// Paid endpoint - requires x402 payment
app.post("/api/premium-analysis", async (c) => {
  // Check for payment header
  const paymentHeader = c.req.header("X-PAYMENT");

  if (!paymentHeader) {
    // Return 402 with payment requirements
    return c.json({
      error: "Payment Required",
      x402: {
        version: 1,
        amount: X402_CONFIG.prices["premium-analysis"].toString(),
        asset: X402_CONFIG.asset,
        recipient: X402_CONFIG.recipient,
        network: X402_CONFIG.network,
        facilitator: X402_CONFIG.facilitatorUrl,
        description: "Premium DeFi analysis for one token/protocol",
      },
    }, 402);
  }

  // Verify payment
  const isValid = await verifyX402Payment(paymentHeader);
  if (!isValid) {
    return c.json({ error: "Invalid payment" }, 403);
  }

  // Payment verified - serve premium content
  const body = await c.req.json();
  const analysis = await performPremiumAnalysis(body);
  return c.json(analysis);
});
```

### 3. Verify Payment via Facilitator

```typescript
interface X402PaymentPayload {
  x402Version: number;
  payload: {
    signature: string;
    payload: {
      scheme: "exact";
      network: string;
      asset: string;
      from: string;
      to: string;
      amount: string;
      validAfter: number;
      validBefore: number;
      nonce: string;
    };
  };
  network: string;
  asset: string;
  amount: string;
}

async function verifyX402Payment(paymentHeader: string): Promise<boolean> {
  try {
    // Decode the base64-encoded payment
    const paymentJson = Buffer.from(paymentHeader, "base64").toString("utf-8");
    const payment: X402PaymentPayload = JSON.parse(paymentJson);

    // Validate basic fields
    if (payment.x402Version !== 1) return false;
    if (payment.payload.payload.to.toLowerCase() !== X402_CONFIG.recipient.toLowerCase()) return false;
    if (payment.payload.payload.asset.toLowerCase() !== X402_CONFIG.asset.toLowerCase()) return false;

    // Check amount meets minimum
    const amount = parseInt(payment.payload.payload.amount);
    if (amount < X402_CONFIG.prices["premium-analysis"]) return false;

    // Check expiration
    const now = Math.floor(Date.now() / 1000);
    if (now > payment.payload.payload.validBefore) return false;

    // Verify with facilitator (the facilitator executes the payment on-chain)
    const response = await fetch(`${X402_CONFIG.facilitatorUrl}/verify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payment),
      signal: AbortSignal.timeout(30_000),
    });

    return response.ok;
  } catch (error) {
    console.error("x402 verification error:", error);
    return false;
  }
}
```

---

## Client Side: Making x402 Payments

### 1. Setup the x402 Client

```typescript
import { ethers } from "ethers";

// EIP-712 Domain for USDC
const EIP712_DOMAIN = {
  name: "USD Coin",
  version: "2",
  chainId: 43114,  // Avalanche Mainnet (43113 for Fuji)
  verifyingContract: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E", // USDC address
};

// EIP-712 Types for TransferWithAuthorization
const TRANSFER_TYPES = {
  TransferWithAuthorization: [
    { name: "from", type: "address" },
    { name: "to", type: "address" },
    { name: "value", type: "uint256" },
    { name: "validAfter", type: "uint256" },
    { name: "validBefore", type: "uint256" },
    { name: "nonce", type: "bytes32" },
  ],
};
```

### 2. Create and Sign a Payment

```typescript
async function createX402Payment(
  wallet: ethers.Wallet,
  recipient: string,
  amountMicroUSDC: number,
  network: string,
  asset: string
) {
  const now = Math.floor(Date.now() / 1000);
  const nonce = ethers.hexlify(ethers.randomBytes(32));

  const payload = {
    scheme: "exact" as const,
    network,
    asset,
    from: wallet.address,
    to: recipient,
    amount: amountMicroUSDC.toString(),
    validAfter: 0,
    validBefore: now + 3600, // Valid for 1 hour
    nonce,
  };

  // Sign with EIP-712
  const signature = await wallet.signTypedData(
    EIP712_DOMAIN,
    TRANSFER_TYPES,
    {
      from: payload.from,
      to: payload.to,
      value: payload.amount,
      validAfter: payload.validAfter,
      validBefore: payload.validBefore,
      nonce: payload.nonce,
    }
  );

  return {
    x402Version: 1,
    payload: { signature, payload },
    network,
    asset,
    amount: amountMicroUSDC.toString(),
  };
}
```

### 3. Call a Paid Endpoint

```typescript
async function callPaidEndpoint(
  url: string,
  data: Record<string, unknown>,
  privateKey: string
) {
  const wallet = new ethers.Wallet(privateKey);

  // Step 1: Try the endpoint without payment to get requirements
  const probe = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });

  if (probe.status !== 402) {
    // No payment required
    return await probe.json();
  }

  // Step 2: Parse payment requirements
  const requirements = await probe.json();
  const { amount, asset, recipient, network } = requirements.x402;

  // Step 3: Create signed payment
  const payment = await createX402Payment(
    wallet,
    recipient,
    parseInt(amount),
    network,
    asset
  );

  // Step 4: Encode payment as base64 header
  const paymentHeader = Buffer.from(JSON.stringify(payment)).toString("base64");

  // Step 5: Call endpoint with payment
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-PAYMENT": paymentHeader,
    },
    body: JSON.stringify(data),
    signal: AbortSignal.timeout(30_000),
  });

  if (!response.ok) {
    throw new Error(`Payment failed: ${response.status}`);
  }

  return await response.json();
}

// Usage
const result = await callPaidEndpoint(
  "https://agent.example.com/api/premium-analysis",
  { type: "token", address: "0x..." },
  process.env.PRIVATE_KEY!
);
```

---

## Agent-to-Agent Payment Discovery

An agent can discover and pay another agent automatically:

```
┌─────────────────────────────────────────────────────────────────┐
│              AGENT-TO-AGENT PAYMENT DISCOVERY                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Agent A (Client)                     Agent B (Server)          │
│  ────────────────                     ────────────────          │
│                                                                 │
│  1. Read Agent B's registration.json                           │
│     └─ Check: x402Support === true                             │
│                                                                 │
│  2. Call Agent B's endpoint                                    │
│     └─ Receive 402 + payment requirements                      │
│                                                                 │
│  3. Check: Do I have enough USDC?                              │
│     └─ If no: log and skip                                     │
│     └─ If yes: create payment proof                            │
│                                                                 │
│  4. Sign EIP-712 TransferWithAuthorization                     │
│     └─ No on-chain tx needed (gasless for client)              │
│                                                                 │
│  5. Retry request with X-PAYMENT header                        │
│     └─ Facilitator executes payment on-chain                   │
│     └─ Agent B receives USDC                                   │
│     └─ Agent A receives data                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```typescript
import { discoverAgents } from "./x402-client";

// Discover agents from on-chain registry
const agents = await discoverAgents(
  "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432" // Mainnet Identity Registry
);

for (const agent of agents) {
  // Fetch agent's registration metadata
  const response = await fetch(agent.metadataURI);
  const metadata = await response.json();

  // Check if agent supports x402
  if (metadata.x402Support) {
    console.log(`Agent #${agent.agentId} accepts payments`);

    // Find their endpoints
    const webService = metadata.services.find(
      (s: { name: string }) => s.name === "web"
    );

    if (webService) {
      // Try to call a paid endpoint
      try {
        const result = await callPaidEndpoint(
          `${webService.endpoint}api/premium-analysis`,
          { type: "protocol", address: "aave" },
          process.env.PRIVATE_KEY!
        );
        console.log("Paid result:", result);
      } catch (error) {
        console.log("Payment or call failed:", error);
      }
    }
  }
}
```

---

## USDC Setup

### Mainnet (Real USDC)

| Property | Value |
|----------|-------|
| USDC Contract | `0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E` |
| Chain ID | 43114 |
| Decimals | 6 |
| $0.01 | 10000 micro-units |
| $0.10 | 100000 micro-units |
| $1.00 | 1000000 micro-units |

### Fuji Testnet (Test USDC)

| Property | Value |
|----------|-------|
| USDC Contract | `0x5425890298aed601595a70AB815c96711a31Bc65` |
| Chain ID | 43113 |
| Decimals | 6 |
| Faucet | https://faucet.circle.com/ |

### Getting Test USDC on Fuji

1. Go to https://faucet.circle.com/
2. Select "Avalanche Fuji"
3. Enter your wallet address
4. Receive test USDC (free)

---

## Registration: Declaring x402 Support

In your `registration.json`:

```json
{
  "x402Support": true,
  "services": [
    {
      "name": "web",
      "endpoint": "https://your-agent.com/"
    }
  ]
}
```

**Important**: Only set `x402Support: true` if you have at least one endpoint that:
1. Returns 402 status code without payment
2. Includes payment requirements in the response body
3. Accepts and verifies `X-PAYMENT` header
4. Actually charges USDC via a facilitator

---

## Pricing Best Practices

| Endpoint Type | Suggested Price | Reasoning |
|--------------|-----------------|-----------|
| Basic data query | $0.001 - $0.01 | Low friction, high volume |
| Analytics / aggregation | $0.01 - $0.10 | Moderate compute |
| Deep research / AI-powered | $0.10 - $1.00 | High compute, unique value |
| Custom report generation | $1.00 - $10.00 | Significant resources |

### Tips

- Start with very low prices ($0.01) to encourage adoption
- Clearly document which endpoints are free vs paid
- In your registration description, state: "X free endpoints, Y paid endpoints"
- Always have free endpoints — agents won't trust you if everything is paid
- Monitor payment volume and adjust prices based on demand

---

## Environment Variables

```bash
# Required for x402 server
X402_RECIPIENT=0xYourWalletAddress        # Receives USDC payments
USDC_CONTRACT=0xB97EF9...                 # USDC address on your chain
X402_NETWORK=avalanche                     # Network identifier

# Required for x402 client
PRIVATE_KEY=0xYourPrivateKey              # Signs payments
FACILITATOR_URL=https://facilitator...     # Payment verifier
X402_CHAIN_ID=43114                        # Chain ID
```

---

## Security Checklist

- [ ] Never expose your private key in code or logs
- [ ] Validate payment amount meets your minimum price
- [ ] Verify the `to` address matches YOUR wallet
- [ ] Check `validBefore` hasn't expired
- [ ] Use the facilitator for verification (don't verify signatures yourself)
- [ ] Set timeouts on facilitator calls (30s max)
- [ ] Log all payment attempts for auditing
- [ ] Use testnet (Fuji) for development, mainnet for production

---

*Guide created by Cyber Paisa based on real x402 implementation in AvaBuilder Agent.*
