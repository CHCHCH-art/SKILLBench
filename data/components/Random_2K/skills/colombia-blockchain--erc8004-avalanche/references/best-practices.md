# ERC-8004 Agent Best Practices

Guide based on real experience building and registering AI agents on Avalanche. These best practices ensure your agent scores well in scanners (8004scan.io, erc-8004scan.xyz), avoids metadata warnings, and presents a professional, trustworthy identity.

---

## 1. Registration Metadata (`registration.json`)

Your `registration.json` is your agent's public identity. Scanners parse it, other agents read it, and users evaluate your agent based on it.

### Structure

```json
{
  "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  "name": "Agent Name",
  "description": "Honest, detailed description of what your agent does",
  "image": "https://your-domain.com/agent-image.png",
  "services": [...],
  "x402Support": false,
  "active": true,
  "registrations": [...],
  "supportedTrust": ["reputation"],
  "capabilities": [...]
}
```

### Best Practices

- **`type`**: Always use `https://eips.ethereum.org/EIPS/eip-8004#registration-v1`. Never change this.
- **`name`**: Short, memorable, unique. Avoid generic names like "AI Agent" or "My Bot".
- **`active`**: Set to `true` when your agent is live. Set to `false` if you take it offline. Scanners check this.
- **`supportedTrust`**: Only list trust models you actually support. `["reputation"]` is the most common.

---

## 2. Description: Be Honest and Detailed

The description is the most important text field. Scanners display it publicly, and it directly affects your **Compliance** and **Service** scores.

### DO

- Describe what your agent actually does, not what you wish it did
- List specific capabilities backed by real code (e.g., "10 callable MCP tools", "20 API endpoints")
- Mention the protocols you support (A2A, MCP, x402) with specifics
- Include how many endpoints are free vs paid
- Describe NLP capabilities if you have them (e.g., "receives natural language questions and synthesizes technical answers")
- Mention data sources (e.g., "DeFiLlama, CoinGecko, Glacier API")
- State who created the agent

### DON'T

- Claim capabilities you haven't implemented
- List services in metadata that return 404
- Say "autonomous" if your agent only provides guided information
- Exaggerate scope (e.g., "all blockchains" when you only cover Avalanche)

### Example of an honest description

> "AvaBuilder delivers real-time DeFi analytics (TVL, 50+ protocols) via DeFiLlama, CoinGecko, and DEX Screener APIs; visibility into 500+ active L1 blockchains via Glacier API; 8 build templates; 3 learning paths; and an AI-powered builder guide backed by 128K+ lines of documentation. 20 API endpoints total (19 free, 1 paid)."

---

## 3. Agent Image / NFT

The image is your agent's visual identity in scanners and registries. It appears as the agent's profile picture on 8004scan.io.

### Requirements

- **Format**: PNG or JPG (PNG recommended for transparency)
- **Size**: Minimum 256x256px, recommended 512x512px
- **Hosting**: Must be publicly accessible via HTTPS (no authentication)
- **URL stability**: The URL must remain valid. If it breaks, scanners show a broken image
- **Content**: Professional, distinctive, recognizable. Avoid generic stock images

### Best Practices

- Host the image on the same domain as your agent (e.g., `https://your-agent.com/public/agent.png`)
- Use a unique design that represents your agent's purpose
- Test the URL in an incognito browser to confirm public access
- The image URL in `registration.json` must match what's accessible. Mismatches generate scanner warnings

---

## 4. Services: Expose What You Actually Have

Services define how other agents and users can interact with yours. Each service you declare must be **live and responding**.

### Available Service Types

| Service | Purpose | When to Include |
|---------|---------|-----------------|
| `web` | Dashboard / UI for humans | If you have a web interface |
| `A2A` | Agent-to-Agent communication | If you serve an `agent-card.json` |
| `MCP` | Model Context Protocol | If you implement JSON-RPC with `tools/list` and `tools/call` |
| `OASF` | Open Agent Service Framework | If you use OASF |
| `ENS` | Ethereum Name Service | If you have an ENS name |
| `email` | Contact email | For human contact |

### Understanding the 4 Protocols: Restaurant Analogy

Think of your agent as a restaurant. Each protocol is a different way for customers (other agents or users) to interact with it:

| Protocol | Analogy | What it does |
|----------|---------|-------------|
| **web** | The restaurant facade | People walk by, see the place, and walk in. Your dashboard for humans. |
| **A2A** | The waiter who talks to customers | "What do you recommend?" → "I recommend today's special." Natural language Q&A. |
| **MCP** | The menu with prices and photos | The customer sees exactly what dishes are available and orders by name. Structured tool calls. |
| **OASF** | The sign outside: "Italian food, pizza, pasta, wine" | Someone looking for pizza sees your sign from the street and knows you have it. Discovery by skills and domains. |

**Without OASF**: Another agent has to enter, read the menu, talk to the waiter... just to know if you can help.

**With OASF**: Another agent sees your sign from afar: "This agent knows blockchain, DeFi, and Avalanche. That's what I need." And walks in directly.

**Cost of OASF**: $0. It's just a GET endpoint that returns a static JSON. No external APIs, no LLM calls. It's like putting a sign on your door.

### Critical Rules

1. **Never declare a service you haven't implemented.** Scanners probe endpoints and flag 404s
2. **A2A requires** a valid `agent-card.json` at the declared endpoint
3. **MCP requires** a POST endpoint that responds to JSON-RPC methods: `initialize`, `tools/list`, `tools/call`
4. **OASF requires** a GET endpoint returning skills and domains classification
5. **Web service** should return a 200 status with your dashboard or landing page
6. **Version field**: Include the protocol version (e.g., A2A `"0.3.0"`, MCP `"2025-06-18"`, OASF `"v0.8.0"`)

### Example: Four Services with Enriched Metadata

Basic services get you listed. **Enriched services** get you ranked higher. The difference is adding detail about what each service offers:

```json
"services": [
  {
    "name": "web",
    "endpoint": "https://your-agent.com/"
  },
  {
    "name": "A2A",
    "endpoint": "https://your-agent.com/.well-known/agent-card.json",
    "version": "0.3.0",
    "a2aSkills": [
      "natural_language_processing/information_retrieval_synthesis/search",
      "natural_language_processing/conversation/chatbot",
      "tool_interaction/api_schema_understanding",
      "tool_interaction/workflow_automation"
    ]
  },
  {
    "name": "MCP",
    "endpoint": "https://your-agent.com/mcp",
    "version": "2025-06-18",
    "mcpTools": [
      "getPrice",
      "getTVL",
      "getProtocols",
      "searchToken",
      "askGuide"
    ],
    "mcpPrompts": [
      "guide",
      "analytics"
    ]
  },
  {
    "name": "OASF",
    "version": "v0.8.0",
    "endpoint": "https://your-agent.com/oasf",
    "skills": [
      "natural_language_processing/information_retrieval_synthesis/search",
      "natural_language_processing/conversation/chatbot",
      "tool_interaction/automation/workflow_automation"
    ],
    "domains": [
      "technology/blockchain/avalanche",
      "finance/defi/analytics",
      "technology/software_engineering/apis_integration"
    ]
  }
]
```

### Why Enriched Metadata Matters

Top-ranked agents (like Rank #1) don't just list their services — they describe exactly what's inside each one:

| Field | Where | Purpose |
|-------|-------|---------|
| `mcpTools` | MCP service | Lists every tool by name — scanners verify each one works |
| `mcpPrompts` | MCP service | Lists prompt templates your MCP server supports |
| `a2aSkills` | A2A service | Lists what your agent can do in natural language |
| `skills` | OASF service | Standardized skill categories for discovery |
| `domains` | OASF service | What areas your agent specializes in |

Agents with enriched metadata score higher in **Service (25%)** and **Compliance (15%)** dimensions.

### Additional Fields for Scanner Ranking

```json
"pricePerMessage": "Free",
"updatedAt": 1739577600
```

- **pricePerMessage**: Tells other agents and users if interacting with you costs money. `"Free"` for free agents.
- **updatedAt**: Unix timestamp of your last metadata update. Shows the scanner your agent is actively maintained.

### MCP Implementation Checklist

If you declare MCP, your endpoint must handle:

- `POST /mcp` with `Content-Type: application/json`
- JSON-RPC 2.0 format with `jsonrpc`, `method`, `id`, `params`
- Method `initialize` → returns server info and capabilities
- Method `tools/list` → returns array of tools with `name`, `description`, `inputSchema`
- Method `tools/call` → executes a tool and returns results
- Each tool must have a complete JSON Schema for its inputs
- Tools should match your actual capabilities (don't list tools that don't work)
- List your tools in `mcpTools` inside the MCP service metadata

### OASF Implementation Checklist

If you declare OASF, your endpoint must:

- `GET /oasf` returns JSON with agent info, skills, and domains
- Skills use standardized hierarchical format (e.g., `natural_language_processing/conversation/chatbot`)
- Domains describe your area of expertise (e.g., `technology/blockchain/avalanche`)
- Cost: $0 — it's a static JSON response, no external APIs needed

---

## 5. Capabilities: Define What Your Agent Can Do

Capabilities tell scanners and other agents what your agent specializes in. They affect your **Service** score.

### Rules

1. **Only list capabilities backed by real, working code**
2. **Use descriptive, kebab-case names** (e.g., `defi-analytics`, `l1-blockchain-guide`)
3. **Use hierarchical names for standard categories** (e.g., `natural_language_processing/information_retrieval_synthesis/search`)
4. **Each capability should map to at least one working endpoint or tool**

### Agent Type Classification

Understanding your agent's type affects how you describe capabilities:

| Type | Definition | Example |
|------|-----------|---------|
| **Agentic** | Executes actions autonomously (trades, deploys contracts, sends transactions) | A trading bot that executes swaps |
| **Hybrid** | Combines autonomous actions with guided information | An agent that provides analytics AND can make payments |
| **Informational** | Provides data, guides, and answers but doesn't execute transactions | A documentation guide with DeFi analytics |

**Be honest about your type.** An informational agent with great data is more valuable than a fake "autonomous" agent that doesn't work.

### Standard Capability Categories

```
natural_language_processing/information_retrieval_synthesis/search
tool_interaction/api_schema_understanding
tool_interaction/workflow_automation
```

- **NLP/search**: Your agent can receive natural language questions and return synthesized answers
- **API schema understanding**: Other agents can discover your tools via `tools/list` and invoke them programmatically
- **Workflow automation**: Your tools are composable — external agents can chain them into multi-step workflows

Only claim these if:
- NLP: You have a knowledge base + LLM that processes questions and returns answers
- API schema: You have MCP with complete JSON schemas for every tool
- Workflow automation: Your MCP tools can be called independently and combined by external agents

### Custom Capabilities

Define domain-specific capabilities that match your agent's real functions:

```json
"capabilities": [
  "ecosystem-explorer",
  "defi-analytics",
  "l1-blockchain-guide",
  "build-templates",
  "learning-paths",
  "agent-discovery",
  "x402-payments"
]
```

---

## 6. Avoiding Scanner Warnings

Scanners like 8004scan.io validate your agent metadata and flag issues. Common warnings and how to avoid them:

### WA080: On-chain vs Off-chain Metadata Conflict

**Cause**: The metadata registered on-chain (via `tokenURI`) doesn't match your hosted `registration.json`.

**Fix**:
1. After updating `registration.json`, also update the on-chain URI if it points to a different version
2. If using IPFS, re-pin and update the on-chain URI with the new CID
3. If using HTTPS, ensure the URL in `tokenURI` serves the latest version
4. Keep `registrations` array in sync — the `agentId` and `agentRegistry` must match your actual on-chain registration

### Other Common Warnings

| Warning | Cause | Fix |
|---------|-------|-----|
| Missing image | Image URL returns 404 | Fix the URL, ensure public access |
| Unreachable service | Declared service endpoint is down | Remove the service or fix the endpoint |
| Invalid JSON | Malformed registration.json | Validate your JSON (use `jq .` to check) |
| Missing type field | No `type` in registration | Add the required `type` field |
| Inactive agent | `active: false` | Set to `true` if your agent is live |

### Pre-registration Checklist

Before registering or updating your agent:

- [ ] Validate JSON syntax: `cat registration.json | jq .`
- [ ] All service endpoints return 200
- [ ] Image URL is publicly accessible
- [ ] `agentId` and `agentRegistry` match your on-chain data
- [ ] Description accurately reflects current capabilities
- [ ] No declared capabilities without working code
- [ ] `active` is set correctly
- [ ] `x402Support` matches reality (do you actually accept x402 payments?)

---

## 7. Scanner Score Optimization

Scanners score agents across 5 dimensions:

| Dimension | Weight | What it Measures |
|-----------|--------|-----------------|
| **Engagement** | 30% | Interactions, feedback received, usage |
| **Service** | 25% | Service availability, response quality, uptime |
| **Publisher** | 20% | Creator reputation, domain verification, history |
| **Compliance** | 15% | Metadata validity, format adherence, no warnings |
| **Momentum** | 10% | Recent activity, updates, growth |

### How to Improve Each Score

**Engagement (30%)**:
- Ensure your endpoints actually work and provide value
- Encourage users and other agents to give reputation feedback
- Respond to feedback on-chain using the Reputation Registry

**Service (25%)**:
- Keep all declared endpoints alive and responding
- Implement proper error handling (don't return 500s)
- Maintain low response times (< 5 seconds)
- Have multiple services (web + A2A + MCP scores higher than web alone)

**Publisher (20%)**:
- Set up domain verification: publish `/.well-known/agent-registration.json`
- Use a consistent domain across all services
- Maintain a professional web presence

**Compliance (15%)**:
- Zero warnings in metadata validation
- Complete all required fields
- Keep on-chain and off-chain metadata in sync
- Use the correct `type` field format

**Momentum (10%)**:
- Update your agent regularly
- Add new capabilities over time
- Stay active in the ecosystem

---

## 8. On-chain vs Off-chain Consistency

This is the #1 cause of warnings. Your agent has two sources of truth:

1. **On-chain**: The `tokenURI` stored in the Identity Registry contract
2. **Off-chain**: Your hosted `registration.json` file

### Rules

- If `tokenURI` points to an HTTPS URL, that URL must serve your current `registration.json`
- If `tokenURI` points to IPFS, the content at that CID is immutable — update the on-chain URI when you change metadata
- The `registrations` array in your JSON must include your actual on-chain `agentId`
- If you're registered on multiple chains (e.g., Mainnet + Fuji), include all registrations:

```json
"registrations": [
  {
    "agentId": 15,
    "agentRegistry": "eip155:43113:0x8004A818BFB912233c491871b3d84c89A494BD9e"
  },
  {
    "agentId": 1686,
    "agentRegistry": "eip155:43114:0x8004A169FB4a3325136EB29fA0ceB6D2e539a432"
  }
]
```

### Update Workflow

When you update your agent:

1. Update `registration.json` in your codebase
2. Deploy the updated file to your hosting (Railway, Vercel, etc.)
3. Verify the hosted URL serves the new version: `curl -s https://your-agent.com/registration.json | jq .name`
4. If using IPFS: re-pin and call `setAgentURI(agentId, newIPFSUri)` on-chain
5. If using HTTPS with same URL: call `setAgentURI` anyway to force Snowtrace and scanners to refresh cached metadata
6. Verify in scanner: check 8004scan.io for your agent and confirm no new warnings

```bash
# Force metadata refresh (even if URL didn't change)
./scripts/update-uri.sh <agent-id> "https://your-agent.up.railway.app/registration.json"
```

### Root URL Must Serve HTML

The `web` service endpoint in your `registration.json` is what scanners link to. When users click it, they expect a **visual webpage**, not raw JSON.

```typescript
// WRONG - users see raw JSON and think the site is broken
app.get("/", (c) => c.json({ status: "ok" }));

// RIGHT - users see a visual dashboard
app.get("/", (c) => c.html(dashboardHTML));

// Move health check to a separate endpoint
app.get("/api/health", (c) => c.json({ status: "ok", version: "1.0.0" }));
```

Also update `railway.toml` to use the new health check path:
```toml
[deploy]
healthcheckPath = "/api/health"
```

---

## 9. x402 Payment Support

If you declare `"x402Support": true`, you must actually accept x402 micropayments.

### Requirements

- At least one endpoint gated by x402 payment headers
- USDC payment address on Avalanche C-Chain
- Proper 402 Payment Required response with payment details
- A facilitator endpoint for payment verification

### If you don't have x402

Set `"x402Support": false`. Don't claim it for a higher score — scanners and other agents will test it.

---

## 10. Static Information Best Practices

Some agents serve static information (guides, templates, documentation). This is valuable but must be presented honestly.

### DO

- Call them "guides", "templates", "learning paths" — not "autonomous actions"
- Expose them as browsable API endpoints (e.g., `/api/templates`, `/api/learning`)
- Make them available via MCP tools so other agents can access them programmatically
- Keep content updated and accurate

### DON'T

- Claim your agent "builds L1 blockchains" when it provides a step-by-step guide
- List capabilities as autonomous when they're instructional
- Serve outdated documentation

### Good Naming Examples

| Instead of... | Use... |
|--------------|--------|
| `smart-contract-builder` | `smart-contract-guide` |
| `l1-deployer` | `l1-blockchain-guide` |
| `defi-creator` | `defi-architecture-guide` |
| `bridge-builder` | `cross-chain-bridge-guide` |

---

## 11. Real-World Example: AvaBuilder Agent

AvaBuilder Agent (Agent #1686 on Avalanche Mainnet) is a reference implementation:

### What it does right

- **3 services**: web (dashboard), A2A (agent-card.json), MCP (10 tools with full JSON schemas)
- **15 capabilities**: Each mapped to working code and real endpoints
- **Honest description**: Clearly states "guide" for instructional capabilities, "analytics" for data capabilities
- **Live data**: DeFi analytics from DeFiLlama, CoinGecko, DEX Screener; L1 data from Glacier API
- **NLP capability**: Claude-backed AI that processes questions against 128K+ lines of documentation
- **MCP tools**: 10 tools with complete input schemas, discoverable via `tools/list`
- **x402 support**: One paid endpoint, 19 free endpoints — stated honestly in description
- **Professional image**: Custom agent avatar, publicly hosted
- **Multi-chain registration**: Fuji (testing) + Mainnet (production)

### Registration metadata structure

```json
{
  "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  "name": "AvaBuilder Agent",
  "description": "Detailed, honest description of ALL capabilities...",
  "image": "https://your-domain.com/public/agent.png",
  "services": [
    { "name": "web", "endpoint": "https://your-domain.com/" },
    { "name": "A2A", "endpoint": "https://your-domain.com/.well-known/agent-card.json", "version": "0.3.0" },
    { "name": "MCP", "endpoint": "https://your-domain.com/mcp", "version": "2025-06-18" }
  ],
  "x402Support": true,
  "active": true,
  "registrations": [
    { "agentId": 15, "agentRegistry": "eip155:43113:0x8004A818BFB912233c491871b3d84c89A494BD9e" },
    { "agentId": 1686, "agentRegistry": "eip155:43114:0x8004A169FB4a3325136EB29fA0ceB6D2e539a432" }
  ],
  "supportedTrust": ["reputation"],
  "capabilities": [
    "ecosystem-explorer",
    "defi-analytics",
    "l1-blockchain-guide",
    "smart-contract-guide",
    "defi-architecture-guide",
    "cross-chain-bridge-guide",
    "tokenomics-design",
    "sdk-guidance",
    "build-templates",
    "learning-paths",
    "agent-discovery",
    "x402-payments",
    "natural_language_processing/information_retrieval_synthesis/search",
    "tool_interaction/api_schema_understanding",
    "tool_interaction/workflow_automation"
  ]
}
```

---

## 12. Common Mistakes to Avoid

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Declaring MCP without implementing it | Scanner shows unreachable service, lowers Service score | Implement JSON-RPC or remove MCP from services |
| Using a local image path | Image doesn't load in scanners | Host image publicly via HTTPS |
| Claiming autonomous capabilities without code | Misleads users, reduces trust when tested | Use honest labels ("guide" vs "builder") |
| Forgetting to update on-chain URI after metadata change | WA080 warning, lowers Compliance score | Update `tokenURI` on-chain or use stable HTTPS URL |
| Setting `x402Support: true` without payment endpoints | Agents trying to pay you will fail | Set to `false` until implemented |
| Dead code in capabilities list | Listed capability returns errors | Audit capabilities against actual working endpoints |
| No cache on API calls | Slow responses, rate limiting from data providers | Implement TTL-based cache (2-10 min depending on data type) |
| Sequential external API calls | Endpoints timeout (30s+) | Use `Promise.allSettled()` for parallel fetching |

---

## Summary Checklist

Before registering your ERC-8004 agent:

- [ ] `registration.json` is valid JSON with all required fields
- [ ] Name is unique and descriptive
- [ ] Description is honest and detailed (what it does, how, data sources)
- [ ] Image is hosted publicly and URL is stable
- [ ] Every declared service is live and responding
- [ ] MCP implements `initialize`, `tools/list`, `tools/call` (if declared)
- [ ] A2A serves a valid `agent-card.json` (if declared)
- [ ] Capabilities match real, working code
- [ ] `x402Support` reflects reality
- [ ] `registrations` array matches on-chain data
- [ ] On-chain `tokenURI` points to current metadata
- [ ] No scanner warnings when validated
- [ ] Agent type (agentic/hybrid/informational) is correctly represented
- [ ] API endpoints have caching and error handling
- [ ] External API calls use timeouts and parallel fetching

---

*Guide created by Cyber Paisa based on real experience building AvaBuilder Agent (ERC-8004 Agent #1686 on Avalanche Mainnet).*
