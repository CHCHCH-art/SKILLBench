# ERC-8004 Agent: Deployment & Infrastructure Guide

Complete flow from zero to a live, registered agent on Avalanche — including backend deployment on Railway.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    ERC-8004 AGENT ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────────────┐  │
│  │  GitHub   │───▶│   Railway    │───▶│  Live Agent Server    │  │
│  │  Repo     │    │   Build +    │    │                       │  │
│  │           │    │   Deploy     │    │  ├─ GET  /            │  │
│  └──────────┘    └──────────────┘    │  ├─ GET  /health      │  │
│                                      │  ├─ GET  /api/*       │  │
│                                      │  ├─ POST /mcp         │  │
│                                      │  ├─ POST /a2a/*       │  │
│                                      │  └─ GET  /reg.json    │  │
│                                      └───────────┬───────────┘  │
│                                                  │              │
│                              ┌────────────────────┤              │
│                              │                    │              │
│                              ▼                    ▼              │
│                   ┌──────────────┐    ┌───────────────────────┐  │
│                   │  External    │    │  Avalanche C-Chain    │  │
│                   │  APIs        │    │                       │  │
│                   │              │    │  ├─ Identity Registry │  │
│                   │  DeFiLlama   │    │  │  (ERC-721 NFT)    │  │
│                   │  CoinGecko   │    │  ├─ Reputation Reg.  │  │
│                   │  DEXScreener │    │  └─ Validation Reg.  │  │
│                   │  Glacier API │    │                       │  │
│                   └──────────────┘    └───────────────────────┘  │
│                                                  │              │
│                                                  ▼              │
│                                      ┌───────────────────────┐  │
│                                      │  Agent Scanners       │  │
│                                      │                       │  │
│                                      │  8004scan.io          │  │
│                                      │  erc-8004scan.xyz     │  │
│                                      └───────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Creation Flow: Step by Step

```
 START
   │
   ▼
┌─────────────────────────────────┐
│ PHASE 1: PROJECT SETUP         │
│                                 │
│ 1. Create project directory     │
│ 2. npm init / package.json      │
│ 3. Install dependencies         │
│    - hono (web framework)       │
│    - typescript                  │
│    - tsx (runtime)               │
│ 4. Configure tsconfig.json      │
│ 5. Create src/ structure        │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ PHASE 2: BUILD THE AGENT       │
│                                 │
│ 1. src/server.ts                │
│    - HTTP server (Hono)         │
│    - Health endpoint            │
│    - API routes                 │
│    - Dashboard (HTML)           │
│                                 │
│ 2. src/defi-apis.ts (optional)  │
│    - External API integrations  │
│    - Cache layer with TTL       │
│    - Error handling + timeouts  │
│                                 │
│ 3. src/guide.ts (optional)      │
│    - Knowledge base             │
│    - NLP processing             │
│                                 │
│ 4. registration.json            │
│    - Agent metadata             │
│    - Services definition        │
│    - Capabilities list          │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ PHASE 3: IMPLEMENT PROTOCOLS   │
│                                 │
│ A2A (Agent-to-Agent):           │
│ ├─ /.well-known/agent-card.json │
│ └─ POST /a2a/* endpoints        │
│                                 │
│ MCP (Model Context Protocol):   │
│ ├─ POST /mcp                    │
│ ├─ Handle: initialize           │
│ ├─ Handle: tools/list           │
│ └─ Handle: tools/call           │
│                                 │
│ x402 (optional):                │
│ ├─ Payment-gated endpoints      │
│ └─ USDC on Avalanche C-Chain    │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ PHASE 4: LOCAL TESTING         │
│                                 │
│ 1. Run locally: npm run dev     │
│ 2. Test all endpoints           │
│    curl http://localhost:3000/   │
│    curl /health                  │
│    curl /api/*                   │
│    curl -X POST /mcp            │
│ 3. Validate registration.json   │
│    cat registration.json | jq . │
│ 4. Test MCP flow:               │
│    initialize → tools/list      │
│    → tools/call                 │
│ 5. Fix all errors before deploy │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ PHASE 5: DEPLOY TO RAILWAY     │
│                                 │
│ (See detailed Railway section   │
│  below)                         │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ PHASE 6: REGISTER ON-CHAIN     │
│                                 │
│ 1. Get AVAX for gas             │
│    Fuji: faucet.avax.network    │
│    Mainnet: buy/transfer AVAX   │
│                                 │
│ 2. Register on Fuji first       │
│    cast send <IdentityRegistry> │
│    "register(string)"           │
│    "<your-registration-url>"    │
│                                 │
│ 3. Verify in scanner            │
│    Check 8004scan.io            │
│    Fix any warnings             │
│                                 │
│ 4. Register on Mainnet          │
│    Same process, mainnet        │
│    contracts + real AVAX        │
│                                 │
│ 5. Update registration.json     │
│    Add both agentIds to         │
│    "registrations" array        │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ PHASE 7: VALIDATE & MONITOR    │
│                                 │
│ 1. Check scanner scores         │
│ 2. Fix all warnings (WA080...)  │
│ 3. Test from external network   │
│ 4. Verify image loads           │
│ 5. Verify all services respond  │
│ 6. Set up monitoring/alerts     │
│ 7. Iterate and improve          │
└─────────────────────────────────┘
             │
             ▼
          LIVE ✓
```

---

## Railway Deployment: Detailed Guide

### Prerequisites

- GitHub account with your agent repo
- Railway account (railway.app)
- Node.js 18+ project with TypeScript

### Project Structure Required

```
your-agent/
├── src/
│   ├── server.ts          # Main server (Hono)
│   ├── defi-apis.ts       # API integrations (optional)
│   └── guide.ts           # Knowledge base (optional)
├── public/
│   └── agent.png          # Agent image
├── registration.json      # ERC-8004 metadata
├── dashboard.html         # Web UI (optional)
├── package.json
├── tsconfig.json
├── railway.toml           # Railway config
├── .env.example           # Environment template
└── .gitignore
```

### Step 1: Configure `railway.toml`

```toml
[build]
builder = "nixpacks"
buildCommand = "npm install && npm run build"

[deploy]
startCommand = "npm start"
healthcheckPath = "/api/health"
healthcheckTimeout = 300
restartPolicyType = "on_failure"
restartPolicyMaxRetries = 10
```

> **Important**: Use `/api/health` (not `/`) for the health check. The root `/` should serve your dashboard HTML for users visiting from the scanner. Railway needs a JSON endpoint for health checks.

### Step 2: Configure `package.json` Scripts

```json
{
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js"
  }
}
```

### Step 3: Server Port Configuration

Railway assigns a dynamic port via `PORT` environment variable. Your server must use it:

```typescript
const port = parseInt(process.env.PORT || "3000");
serve({ fetch: app.fetch, port });
```

### Step 4: Deploy to Railway

1. Go to railway.app → New Project → Deploy from GitHub Repo
2. Select your repository
3. Railway auto-detects Node.js and builds with Nixpacks
4. Set environment variables in Railway dashboard:

| Variable | Value | Required |
|----------|-------|----------|
| `PORT` | (set by Railway automatically) | Auto |
| `NODE_ENV` | `production` | Yes |
| `PRIVATE_KEY` | Your wallet private key | If using x402 |
| `ANTHROPIC_API_KEY` | Your Claude API key | If using LLM |
| `KNOWLEDGE_BASE_PATH` | `/app/knowledge-base` | If using local files |

5. Railway generates a URL: `https://your-project-production.up.railway.app`

### Step 5: Serve Static Files

Your agent image and registration.json must be publicly accessible:

```typescript
// Serve agent image
app.get("/public/:filename", async (c) => {
  const filePath = path.join(process.cwd(), "public", c.req.param("filename"));
  const file = await fs.readFile(filePath);
  return new Response(file, {
    headers: { "Content-Type": "image/png" },
  });
});

// Serve registration.json
app.get("/registration.json", async (c) => {
  const reg = await fs.readFile("registration.json", "utf-8");
  return c.json(JSON.parse(reg));
});
```

### Step 6: Verify Deployment

```bash
# Health check
curl https://your-agent.up.railway.app/health

# Registration metadata
curl https://your-agent.up.railway.app/registration.json

# Agent image
curl -I https://your-agent.up.railway.app/public/agent.png

# MCP (if implemented)
curl -X POST https://your-agent.up.railway.app/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

---

## Infrastructure Requirements

### Minimum Infrastructure for a Live Agent

```
┌─────────────────────────────────────────────────────┐
│               MINIMUM VIABLE AGENT                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Backend Server (Railway / Vercel / VPS)             │
│  ├─ Node.js 18+ runtime                            │
│  ├─ 512MB RAM minimum                              │
│  ├─ HTTPS endpoint (auto with Railway)              │
│  └─ Always-on (no cold starts for scanners)         │
│                                                     │
│  Domain / URL                                       │
│  ├─ Railway provides: *.up.railway.app              │
│  ├─ Custom domain optional but recommended          │
│  └─ SSL/TLS required (auto with Railway)            │
│                                                     │
│  Avalanche Wallet                                   │
│  ├─ Private key for registration tx                 │
│  ├─ ~0.05 AVAX for gas (Mainnet)                   │
│  ├─ Free AVAX from faucet (Fuji)                   │
│  └─ USDC if accepting x402 payments                │
│                                                     │
│  External APIs (free tier)                          │
│  ├─ DeFiLlama (no key needed)                      │
│  ├─ CoinGecko (30 req/min free)                    │
│  ├─ DEX Screener (no key needed)                   │
│  └─ Glacier API (no key needed)                    │
│                                                     │
│  Optional                                           │
│  ├─ Anthropic API key (for LLM/NLP)               │
│  ├─ Pinata JWT (for IPFS hosting)                  │
│  └─ Custom domain + DNS                            │
└─────────────────────────────────────────────────────┘
```

### Cost Estimation

| Resource | Free Tier | Paid |
|----------|-----------|------|
| Railway | 500 hours/month free | ~$5/month (Hobby) |
| Avalanche Gas (Fuji) | Free via faucet | - |
| Avalanche Gas (Mainnet) | - | ~$0.01-0.05 per tx |
| DeFiLlama API | Unlimited | - |
| CoinGecko API | 30 req/min | $129/month (Pro) |
| DEX Screener API | Unlimited | - |
| Glacier API | Unlimited | - |
| Anthropic Claude API | - | ~$3-15/1M tokens |
| IPFS (Pinata) | 1GB free | $20/month |

**Minimum cost to run a basic agent: $0 (Fuji) / ~$5/month (Mainnet with Railway Hobby)**

---

## Backend Code Structure

### Recommended File Organization

```
src/
├── server.ts           # Entry point: routes, middleware, startup
├── defi-apis.ts        # External API integrations with cache
├── guide.ts            # Knowledge base / NLP processing
├── x402-client.ts      # x402 payment client (optional)
└── types.ts            # Shared TypeScript interfaces (optional)
```

### Essential Server Components

```typescript
// server.ts - Essential structure

import { Hono } from "hono";
import { cors } from "hono/cors";
import { serve } from "@hono/node-server";

const app = new Hono();

// 1. CORS - Required for dashboard and cross-origin MCP calls
app.use("/*", cors());

// 2. Dashboard at root - Required for scanner "Web" link to show a visual page
app.get("/", (c) => c.html(dashboardHTML));

// 3. Health endpoint - Required by Railway healthcheck (must return JSON)
app.get("/api/health", (c) => c.json({ status: "ok", version: "1.0.0" }));

// 4. Registration metadata - Must be publicly accessible
app.get("/registration.json", (c) => c.json(registrationData));

// 5. Agent image - Must be publicly accessible
app.get("/public/:file", serveStaticFile);

// 6. API routes - Your agent's capabilities
app.get("/api/data", handler);

// 7. A2A - Agent-to-Agent (if declared in services)
app.get("/.well-known/agent-card.json", (c) => c.json(agentCard));

// 8. MCP - Model Context Protocol (if declared in services)
app.post("/mcp", mcpHandler);

// 9. Start server
const port = parseInt(process.env.PORT || "3000");
serve({ fetch: app.fetch, port });
```

### Cache Strategy

Every external API call MUST be cached to avoid rate limits and slow responses:

```
┌──────────────────────────────────────────────┐
│            CACHE TTL RECOMMENDATIONS         │
├──────────────────────────────────────────────┤
│                                              │
│  Price data (CoinGecko)     →  2 minutes     │
│  DEX pairs (DEX Screener)   →  2 minutes     │
│  Protocol list (DeFiLlama)  →  5 minutes     │
│  TVL data (DeFiLlama)       →  10 minutes    │
│  L1/Subnet data (Glacier)   →  3 minutes     │
│  Static content (guides)    →  30 minutes    │
│                                              │
│  Implementation: SimpleCache<T> with TTL     │
│  + Periodic cleanup to prevent memory leaks  │
└──────────────────────────────────────────────┘
```

### Timeout Strategy

All external API calls must have timeouts:

```typescript
// Always use AbortSignal.timeout
const response = await fetch(url, {
  signal: AbortSignal.timeout(15_000), // 15 seconds max
});
```

### Parallel API Calls

When fetching from multiple APIs, use `Promise.allSettled` (not `Promise.all`):

```typescript
// Good: One failed API doesn't break everything
const results = await Promise.allSettled([
  fetchFromDeFiLlama(),
  fetchFromCoinGecko(),
  fetchFromDEXScreener(),
]);

// Bad: One failure rejects everything
const results = await Promise.all([...]);
```

---

## On-Chain Registration Flow

```
┌──────────────────────────────────────────────────────────┐
│                ON-CHAIN REGISTRATION FLOW                │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  1. PREPARE                                              │
│     │                                                    │
│     ├─ Deploy agent to Railway (get HTTPS URL)           │
│     ├─ Verify /registration.json is accessible           │
│     ├─ Verify /health returns 200                        │
│     └─ Verify agent image loads                          │
│         │                                                │
│  2. FUND WALLET                                          │
│     │                                                    │
│     ├─ Fuji: Get test AVAX from faucet.avax.network     │
│     └─ Mainnet: Transfer real AVAX (~0.05 for gas)      │
│         │                                                │
│  3. REGISTER (Fuji first, then Mainnet)                  │
│     │                                                    │
│     ├─ Call: IdentityRegistry.register(agentURI)        │
│     ├─ agentURI = URL to your registration.json         │
│     ├─ Transaction costs ~0.01-0.05 AVAX in gas         │
│     └─ Returns: agentId (your NFT token ID)             │
│         │                                                │
│  4. UPDATE METADATA                                      │
│     │                                                    │
│     ├─ Add agentId to registration.json                 │
│     ├─ Add agentRegistry (chain:address format)         │
│     ├─ Redeploy to Railway                              │
│     └─ Verify scanner shows no warnings                 │
│         │                                                │
│  5. VERIFY                                               │
│     │                                                    │
│     ├─ Check 8004scan.io/agent/<agentId>                │
│     ├─ Verify: name, description, image display         │
│     ├─ Verify: all services are marked as reachable     │
│     ├─ Verify: no WA080 or other warnings               │
│     └─ Verify: capabilities are listed correctly        │
│         │                                                │
│  6. OPTIONAL: Domain Verification                        │
│     │                                                    │
│     └─ Publish /.well-known/agent-registration.json     │
│        on your domain with matching registrations        │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Monitoring & Maintenance

### Keep Your Agent Alive

```
┌──────────────────────────────────────────────┐
│           AGENT HEALTH MONITORING            │
├──────────────────────────────────────────────┤
│                                              │
│  Daily:                                      │
│  ├─ Check Railway deployment status          │
│  ├─ Verify /health endpoint responds         │
│  └─ Check Railway logs for errors            │
│                                              │
│  Weekly:                                     │
│  ├─ Check scanner score                      │
│  ├─ Verify all API integrations work         │
│  ├─ Review API rate limit usage              │
│  └─ Check for new scanner warnings           │
│                                              │
│  Monthly:                                    │
│  ├─ Update dependencies (npm update)         │
│  ├─ Review and update description            │
│  ├─ Add new capabilities if developed        │
│  └─ Check for ERC-8004 spec updates         │
│                                              │
│  On Every Update:                            │
│  ├─ Test locally first                       │
│  ├─ Push to GitHub → Railway auto-deploys    │
│  ├─ Verify deployment succeeded              │
│  ├─ Check scanner for new warnings           │
│  └─ Update on-chain URI if using IPFS        │
└──────────────────────────────────────────────┘
```

### Common Railway Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Build fails | TypeScript errors | Fix errors locally, `npm run build` |
| App crashes on start | Missing env vars | Set all required vars in Railway dashboard |
| 502 Bad Gateway | Wrong port | Use `process.env.PORT` |
| Slow cold starts | Free tier sleeps | Upgrade to Hobby ($5/month) for always-on |
| Out of memory | No cache cleanup | Add periodic cache cleanup intervals |
| Timeout on API calls | No AbortSignal | Add `AbortSignal.timeout(15_000)` to all fetches |

---

## Security Considerations

```
┌──────────────────────────────────────────────┐
│           SECURITY CHECKLIST                 │
├──────────────────────────────────────────────┤
│                                              │
│  ✓ Never commit private keys to Git          │
│  ✓ Use .env for local, Railway vars for prod │
│  ✓ Add .env to .gitignore                    │
│  ✓ Validate all user inputs                  │
│  ✓ Rate limit public endpoints               │
│  ✓ Use CORS appropriately                    │
│  ✓ Set timeouts on all external calls        │
│  ✓ Don't expose internal errors to users     │
│  ✓ Validate address formats (0x + 40 hex)    │
│  ✓ Use HTTPS only (Railway provides this)    │
└──────────────────────────────────────────────┘
```

---

## Quick Reference: Registration Commands

```bash
# ========== FUJI TESTNET ==========

# Get test AVAX
# Visit: https://faucet.avax.network

# Register agent
cast send 0x8004A818BFB912233c491871b3d84c89A494BD9e \
  "register(string)" \
  "https://your-agent.up.railway.app/registration.json" \
  --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
  --private-key $PRIVATE_KEY

# Check your agent
cast call 0x8004A818BFB912233c491871b3d84c89A494BD9e \
  "tokenURI(uint256)" <your-agent-id> \
  --rpc-url https://api.avax-test.network/ext/bc/C/rpc

# ========== MAINNET ==========

# Register agent
cast send 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432 \
  "register(string)" \
  "https://your-agent.up.railway.app/registration.json" \
  --rpc-url https://api.avax.network/ext/bc/C/rpc \
  --private-key $PRIVATE_KEY

# Verify in scanner
# Visit: https://8004scan.io
```

---

*Guide created by Cyber Paisa based on real experience deploying AvaBuilder Agent on Railway and registering on Avalanche Mainnet (Agent #1686).*
