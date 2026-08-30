# ERC-8004 Agent Troubleshooting Guide

Real-world problems and solutions from building and operating AvaBuilder Agent on Avalanche. Every issue documented here was encountered in production.

---

## Scanner Warnings

### WA080: On-chain vs Off-chain Metadata Conflict

```
WARNING WA080: Conflict between on-chain and off-chain metadata
```

**What happened**: After updating `registration.json` and redeploying, the scanner detected differences between what's registered on-chain (`tokenURI`) and what's hosted at the URL.

**Root cause**: The on-chain `tokenURI` pointed to an older version of the metadata. The hosted file was updated but the on-chain pointer wasn't.

**Fix**:
```bash
# If using HTTPS URL (same URL, content changed) - no on-chain update needed
# The scanner may take 24h to re-crawl

# If using IPFS (content changed = new CID) - must update on-chain
cast send 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432 \
  "setAgentURI(uint256,string)" \
  <your-agent-id> "ipfs://NEW_CID" \
  --rpc-url https://api.avax.network/ext/bc/C/rpc \
  --private-key $PRIVATE_KEY
```

**Prevention**: Use HTTPS hosting (not IPFS) if you update metadata frequently. The scanner will always read the latest version.

---

### Unreachable Service Endpoint

```
WARNING: Service endpoint unreachable - MCP at https://mcp.agent.com/
```

**What happened**: The MCP endpoint was declared in `registration.json` but returned 404.

**Root cause**: The MCP service was listed in metadata before the code was implemented.

**Fix**: Either implement the endpoint or remove the service from `registration.json`:

```json
// WRONG - declaring service that doesn't exist
"services": [
  { "name": "MCP", "endpoint": "https://agent.com/mcp", "version": "2025-06-18" }
]

// RIGHT - only declare working services
"services": [
  { "name": "web", "endpoint": "https://agent.com/" }
]
```

**Prevention**: Never declare a service in metadata until the endpoint is deployed and tested.

---

## Railway Deployment Issues

### 502 Bad Gateway After Deploy

```
502 Bad Gateway
```

**What happened**: Railway deployed successfully but the app wasn't reachable.

**Root cause**: The server was listening on a hardcoded port (3000) instead of Railway's dynamic `PORT` environment variable.

**Fix**:
```typescript
// WRONG
serve({ fetch: app.fetch, port: 3000 });

// RIGHT
const port = parseInt(process.env.PORT || "3000");
serve({ fetch: app.fetch, port });
```

---

### Build Fails: TypeScript Errors

```
error TS2307: Cannot find module './defi-analyzer'
```

**What happened**: A file was deleted (`defi-analyzer.ts`) but was still imported in `server.ts`.

**Root cause**: Dead code cleanup removed a file without removing all imports.

**Fix**: Remove all imports and references to deleted files:
```typescript
// Remove this line from server.ts
import { DeFiAnalyzer } from "./defi-analyzer";

// Also remove any usage of DeFiAnalyzer in the code
```

**Prevention**: After deleting any file, search for all imports:
```bash
grep -r "defi-analyzer" src/
```

---

### App Crashes: Missing Environment Variables

```
Error: ANTHROPIC_API_KEY is required
```

**What happened**: The app started but crashed because it required an API key that wasn't set in Railway.

**Root cause**: Environment variables were set locally in `.env` but not configured in Railway dashboard.

**Fix**:
1. Go to Railway dashboard → Your project → Variables
2. Add all required environment variables
3. Redeploy

**Prevention**: Create a `.env.example` file listing all required variables:
```bash
# .env.example
PORT=3000
NODE_ENV=production
ANTHROPIC_API_KEY=sk-ant-...       # Required for AI guide
PRIVATE_KEY=0x...                   # Required for x402
KNOWLEDGE_BASE_PATH=/app/knowledge  # Optional
```

---

### Knowledge Base Path Not Found

```
Error: ENOENT: no such file or directory '/Users/jquiceva/avalanche-skill/knowledge-base'
```

**What happened**: The app worked locally but crashed on Railway because it used a hardcoded local file path.

**Root cause**: The knowledge base path was hardcoded to a developer's local machine path.

**Fix**:
```typescript
// WRONG - hardcoded local path
const KNOWLEDGE_BASE = "/Users/jquiceva/avalanche-skill/knowledge-base";

// RIGHT - relative path with env var fallback
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const KNOWLEDGE_BASE = process.env.KNOWLEDGE_BASE_PATH
  || join(__dirname, "..", "knowledge-base");
```

**Prevention**: Never use absolute paths in source code. Always use relative paths or environment variables.

---

## API Integration Issues

### CEXs Appearing in DeFi Protocol Data

```
Top protocols: Binance CEX ($45B), OKX ($12B), Aave ($2B)...
```

**What happened**: The `/api/defi` endpoint returned centralized exchanges (Binance, OKX) in the DeFi protocol list, inflating TVL numbers.

**Root cause**: DeFiLlama's `/protocols` endpoint includes CEX protocols. No category filter was applied.

**Fix**:
```typescript
// WRONG - no filtering
const avaxProtocols = protocols.filter(p => p.chains?.includes("Avalanche"));

// RIGHT - exclude CEX and Chain categories
const excludeCategories = ["CEX", "Chain"];
const avaxProtocols = protocols
  .filter(p =>
    p.chains?.includes("Avalanche") &&
    !excludeCategories.includes(p.category || "")
  );
```

---

### Sequential API Calls Causing Timeouts

```
Error: Request timeout after 30000ms
GET /api/dex-pairs took 42 seconds
```

**What happened**: The top DEX pairs endpoint was calling 4 different token addresses sequentially, each taking ~10 seconds.

**Root cause**: `for...of` loop with `await` inside, making calls one at a time.

**Fix**:
```typescript
// WRONG - sequential (40+ seconds)
const allPairs = [];
for (const token of topTokens) {
  const response = await fetch(`https://api.dexscreener.com/latest/dex/tokens/${token}`);
  const data = await response.json();
  allPairs.push(...data.pairs);
}

// RIGHT - parallel (10 seconds max)
const results = await Promise.allSettled(
  topTokens.map(token =>
    fetch(`https://api.dexscreener.com/latest/dex/tokens/${token}`, {
      signal: AbortSignal.timeout(10_000),
    }).then(r => r.ok ? r.json() : { pairs: null })
  )
);

const allPairs = [];
for (const result of results) {
  if (result.status === "fulfilled") {
    allPairs.push(...(result.value.pairs || []).filter(p => p.chainId === "avalanche"));
  }
}
```

**Key insight**: Use `Promise.allSettled` (not `Promise.all`) so one failed API doesn't break everything.

---

### Memory Leaks from Uncleaned Caches

```
Railway: Memory usage 95% - container restart triggered
```

**What happened**: After days of running, the app's memory kept growing until Railway killed the container.

**Root cause**: `SimpleCache` and `RateLimiter` Maps grew indefinitely — expired entries were never removed.

**Fix**:
```typescript
class SimpleCache<T> {
  private cache = new Map<string, { data: T; expires: number }>();

  constructor(private ttlMs: number = 5 * 60 * 1000) {
    // Periodic cleanup every 5 minutes
    setInterval(() => this.cleanup(), 5 * 60 * 1000);
  }

  private cleanup(): void {
    const now = Date.now();
    for (const [key, entry] of this.cache) {
      if (now > entry.expires) this.cache.delete(key);
    }
  }

  // ... get, set methods
}
```

**Prevention**: Every Map, Set, or cache structure that grows over time MUST have a cleanup mechanism.

---

### CoinGecko Rate Limiting

```
Error: 429 Too Many Requests
```

**What happened**: Multiple concurrent users hit the price endpoint, exhausting CoinGecko's free tier (30 req/min).

**Root cause**: No caching — every request to `/api/price` made a fresh call to CoinGecko.

**Fix**: Add a TTL cache with 2-minute expiry:
```typescript
private priceCache = new SimpleCache<CoinGeckoPrice>(2 * 60 * 1000);

async getTokenPrice(tokenId: string): Promise<CoinGeckoPrice | null> {
  const cached = this.priceCache.get(`price:${tokenId}`);
  if (cached) return cached; // Return cache if <2 min old

  const response = await fetch(`https://api.coingecko.com/...`);
  const price = await response.json();
  this.priceCache.set(`price:${tokenId}`, price); // Cache for 2 min
  return price;
}
```

---

## Version & Metadata Issues

### Version Mismatch Across Endpoints

```
GET /health     → { version: "2.0.0" }
Console log     → "AvaBuilder Agent v2.1 started"
registration    → (no version field)
```

**What happened**: Different parts of the code reported different version numbers.

**Root cause**: Version strings were hardcoded in multiple places instead of a single constant.

**Fix**:
```typescript
// Define version ONCE at the top of server.ts
const VERSION = "2.1.0";

// Use everywhere
app.get("/health", (c) => c.json({ status: "ok", version: VERSION }));
console.log(`Agent v${VERSION} started on port ${port}`);
```

---

## On-chain Registration Issues

### Transaction Reverted: Insufficient Gas

```
Error: execution reverted
```

**What happened**: Registration transaction failed on Mainnet.

**Root cause**: Wallet didn't have enough AVAX for gas fees.

**Fix**: Ensure wallet has at least 0.05 AVAX:
```bash
# Check balance
cast balance $WALLET_ADDRESS --rpc-url https://api.avax.network/ext/bc/C/rpc

# If zero, transfer AVAX to the wallet
```

---

### Wrong Agent ID in Registration

```
registration.json: { "agentId": 0 }
On-chain actual: agentId = 1686
```

**What happened**: After registering on-chain, the `registration.json` still had `agentId: 0` (placeholder).

**Root cause**: Forgot to update the JSON file after getting the real agent ID from the registration transaction.

**Fix**:
1. Get your actual agent ID from the registration transaction receipt
2. Update `registration.json` with the correct ID
3. Redeploy

```bash
# Check your agent ID
cast call 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432 \
  "tokenURI(uint256)" <your-agent-id> \
  --rpc-url https://api.avax.network/ext/bc/C/rpc
```

---

## Null Safety Issues

### Subnets Without Blockchains Crash

```
TypeError: Cannot read properties of undefined (reading 'length')
```

**What happened**: Some Glacier API subnet objects didn't have the `blockchains` array.

**Root cause**: Assumed all subnets have blockchains, but some are empty or newly created.

**Fix**:
```typescript
// WRONG
const chainCount = subnet.blockchains.length;

// RIGHT
const chains = subnet.blockchains || [];
const chainCount = chains.length;
```

---

### Address Validation Missing

```
GET /api/dex-pairs/not-an-address → 500 Internal Server Error
```

**What happened**: Passing an invalid string as a token address caused the DEX Screener API to return unexpected data.

**Fix**: Validate addresses before using them:
```typescript
function isValidAddress(address: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

app.get("/api/dex-pairs/:address", async (c) => {
  const address = c.req.param("address");
  if (!isValidAddress(address)) {
    return c.json({ error: "Invalid address format. Expected: 0x + 40 hex characters" }, 400);
  }
  // ... proceed with valid address
});
```

---

## Git & Deployment Issues

### .gitignore Blocking dist/ Upload

```
error: pathspec 'dist/' did not match any file(s) known to git
```

**What happened**: Tried to `git add dist/` but `.gitignore` blocks it.

**Root cause**: Build artifacts shouldn't be in git. Railway builds from source.

**Fix**: Let Railway build the project. Don't commit `dist/`:
```
# .gitignore
node_modules/
dist/
.env
```

Railway handles: `npm install → npm run build → npm start`

---

### Deleted File Still in Git

```
error: pathspec 'src/defi-analyzer.ts' did not match any files
```

**What happened**: Tried to `git add` a file that was already deleted from the filesystem.

**Fix**: Use `git rm` for files that were deleted:
```bash
git rm src/defi-analyzer.ts    # Remove from git tracking
git commit -m "Remove unused defi-analyzer module"
```

---

## Diagnostic Commands

Quick commands to diagnose common issues:

```bash
# ===== Check your agent is alive =====
curl -s https://your-agent.com/health | jq .

# ===== Check registration.json is valid =====
curl -s https://your-agent.com/registration.json | jq .

# ===== Check agent card (A2A) =====
curl -s https://your-agent.com/.well-known/agent-card.json | jq .

# ===== Check MCP responds =====
curl -s -X POST https://your-agent.com/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' | jq '.result.tools | length'

# ===== Check agent image loads =====
curl -sI https://your-agent.com/public/agent.png | grep "HTTP\|Content-Type"

# ===== Check on-chain registration =====
cast call 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432 \
  "tokenURI(uint256)" <agent-id> \
  --rpc-url https://api.avax.network/ext/bc/C/rpc

# ===== Check all API endpoints =====
for endpoint in health api/price api/tvl api/defi api/l1s api/ecosystem api/topics api/templates api/learning; do
  status=$(curl -s -o /dev/null -w "%{http_code}" https://your-agent.com/$endpoint)
  echo "$endpoint: $status"
done

# ===== Check Railway logs =====
railway logs --tail 50
```

---

## Issue Resolution Flowchart

```
┌─────────────────────────────────────────────────────────────┐
│                  ISSUE RESOLUTION FLOW                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Agent not responding?                                      │
│  ├─ Check Railway deployment status                        │
│  ├─ Check PORT env var is set                              │
│  ├─ Check Railway logs for crashes                         │
│  └─ Check if free tier hours are exhausted                 │
│                                                             │
│  Scanner showing warnings?                                  │
│  ├─ WA080 → Sync on-chain URI with hosted JSON            │
│  ├─ Missing image → Fix image URL                          │
│  ├─ Unreachable service → Fix endpoint or remove service   │
│  └─ Invalid JSON → Validate with jq                        │
│                                                             │
│  API returning errors?                                      │
│  ├─ 400 → Check input validation                           │
│  ├─ 404 → Check route is defined                           │
│  ├─ 429 → Add caching                                      │
│  ├─ 500 → Check Railway logs, add try/catch               │
│  └─ Timeout → Add AbortSignal, use Promise.allSettled      │
│                                                             │
│  MCP not working?                                           │
│  ├─ Check POST /mcp returns 200                            │
│  ├─ Check initialize method works                          │
│  ├─ Check tools/list returns tools                         │
│  ├─ Check tools/call returns results                       │
│  └─ Check JSON-RPC format (jsonrpc: "2.0")                │
│                                                             │
│  On-chain registration failed?                              │
│  ├─ Check wallet has AVAX for gas                          │
│  ├─ Check RPC URL is correct                               │
│  ├─ Check private key is valid                             │
│  └─ Check agentURI is a valid URL                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Snowtrace & Metadata Refresh Issues

### Snowtrace Shows Old Image/Description After Update

**What happened**: Updated `registration.json` with new image and description, redeployed to Railway, but Snowtrace still showed the old metadata (placeholder NFT image, old description).

**Root cause**: Snowtrace caches NFT metadata aggressively. Even though the hosted `registration.json` has new data, Snowtrace doesn't re-fetch unless it detects an on-chain event.

**Fix**: Call `setAgentURI` on-chain to emit a `URIUpdated` event, even if the URL hasn't changed:

```bash
# This forces Snowtrace to re-read your metadata
./scripts/update-uri.sh 1686 "https://your-agent.up.railway.app/registration.json"

# Or manually with cast:
cast send 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432 \
  "setAgentURI(uint256,string)" \
  <your-agent-id> "https://your-agent.up.railway.app/registration.json" \
  --rpc-url https://api.avax.network/ext/bc/C/rpc \
  --private-key $PRIVATE_KEY
```

**Timeline**: Image may update within minutes. Description can take longer. If still stale, look for a "Refresh Metadata" button on the Snowtrace NFT page.

**Prevention**: After any metadata change (name, description, image, services), always call `setAgentURI` to signal the update on-chain.

---

## Railway & GitHub Issues

### Auto-Deploy Stops Working After Making Repo Private

**What happened**: Railway was auto-deploying on every push to GitHub. After changing the repo from public to private, pushes no longer triggered deploys. Railway showed the last deploy was hours ago.

**Root cause**: When a GitHub repo changes visibility from public to private, the webhook that Railway uses to detect pushes gets deleted. Railway loses the connection.

**Fix**:
1. Go to Railway dashboard → Your service → **Settings** → **Source**
2. Disconnect the repository
3. Reconnect the repository (Railway will request GitHub permissions for the private repo)
4. Railway recreates the webhook and triggers a new deploy

**Verification**: After reconnecting, push a small change and check that Railway shows "Check updates" or starts a new deploy.

**Prevention**: If you need to make a repo private, reconnect Railway immediately after.

---

### Root URL Returns JSON Instead of Visual Page

**What happened**: Clicking the "Web" link from the ERC-8004 scanner opened the agent URL, but the browser showed raw JSON instead of a visual page. Users reported "site not working".

**Root cause**: The root endpoint `/` returned a JSON health check instead of serving HTML. Browsers display raw JSON, which looks broken to non-technical users.

**Fix**: Serve the dashboard HTML at `/` and move health check to `/api/health`:

```typescript
// WRONG - root returns JSON (looks broken in browser)
app.get("/", (c) => c.json({ status: "ok", agent: "My Agent" }));

// RIGHT - root serves visual dashboard
app.get("/", (c) => {
  const html = readFileSync(join(__dirname, "..", "dashboard.html"), "utf-8");
  return c.html(html);
});

// Health check at a separate endpoint
app.get("/api/health", (c) => c.json({ status: "ok", version: "1.0.0" }));
```

Also update `railway.toml`:
```toml
[deploy]
healthcheckPath = "/api/health"  # NOT "/"
```

**Prevention**: Always serve a visual HTML page at `/`. The scanner link and users expect a webpage, not JSON.

---

### Chainlink Price Decoder Returns Wrong Values

**What happened**: On-chain Chainlink prices were showing incorrect values — either 0, NaN, or wildly wrong numbers.

**Root cause**: Using `parseInt()` to decode `int256` values from ABI-encoded hex. `parseInt` cannot handle:
- Values larger than `Number.MAX_SAFE_INTEGER` (loses precision)
- Negative `int256` values (two's complement encoding)

**Fix**: Use `BigInt` with proper two's complement handling:

```typescript
// WRONG - loses precision, ignores negative values
const answer = parseInt(answerHex, 16);

// RIGHT - handles large values and signed integers
let answer = BigInt("0x" + answerHex);
const MAX_INT256 = BigInt("0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
if (answer > MAX_INT256) {
  answer = answer - BigInt("0x10000000000000000000000000000000000000000000000000000000000000000");
}
const price = Number(answer) / Math.pow(10, feed.decimals);
```

**Prevention**: Always use `BigInt` when decoding ABI-encoded values from smart contracts. Never use `parseInt` for values that could exceed 53 bits.

---

*Guide created by Cyber Paisa from real production issues encountered with AvaBuilder Agent (Agent #1686 on Avalanche Mainnet).*
