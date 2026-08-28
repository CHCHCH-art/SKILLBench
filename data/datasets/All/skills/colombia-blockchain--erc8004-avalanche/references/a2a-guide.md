# A2A: Agent-to-Agent Communication Protocol

Complete guide to implementing the A2A (Agent-to-Agent) protocol for ERC-8004 agents. A2A enables agents to discover, communicate, and collaborate with each other using natural language.

---

## How A2A Works

```
┌──────────────────────────────────────────────────────────────────┐
│                    A2A COMMUNICATION FLOW                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  AGENT A (Client)                    AGENT B (Server)            │
│  ────────────────                    ────────────────            │
│                                                                  │
│  1. Discovery                                                    │
│     │                                                            │
│     ├─ Read Agent B's registration.json                         │
│     ├─ Find A2A service: endpoint + version                     │
│     └─ Fetch agent-card.json                                    │
│                                                                  │
│  2. Understand Capabilities                                      │
│     │                                                            │
│     ├─ Read agent-card.json                                     │
│     ├─ Parse: name, description, skills                         │
│     └─ Decide: can this agent help me?                          │
│                                                                  │
│  3. Communicate                                                  │
│     │                                                            │
│     ├─ POST to A2A endpoint                                     │
│     ├─ Send natural language question or task                   │
│     └─ Receive structured response                              │
│                                                                  │
│  4. Process Response                                             │
│     │                                                            │
│     ├─ Parse response data                                      │
│     ├─ Use in own workflow                                      │
│     └─ Optionally give reputation feedback on-chain             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Server Side: Making Your Agent A2A-Compatible

### 1. Create the Agent Card

The agent card is the A2A discovery file. It tells other agents who you are and what you can do.

**Serve at**: `GET /.well-known/agent-card.json`

```typescript
const agentCard = {
  name: "AvaBuilder Agent",
  description: "Avalanche ecosystem builder guide with real-time DeFi analytics, L1 blockchain data, and AI-powered technical assistance.",
  url: "https://your-agent.com",
  version: "0.3.0",
  capabilities: {
    streaming: false,
    pushNotifications: false,
  },
  skills: [
    {
      id: "avalanche-guide",
      name: "Avalanche Builder Guide",
      description: "Ask technical questions about building on Avalanche. Covers L1 blockchains, smart contracts, DeFi, cross-chain bridges, tokenomics, and SDKs.",
      examples: [
        "How do I create an L1 blockchain on Avalanche?",
        "What is the Avalanche Warp Messaging protocol?",
        "How do I deploy an ERC-20 token on Avalanche?",
      ],
    },
    {
      id: "defi-analytics",
      name: "DeFi Analytics",
      description: "Get real-time DeFi data for Avalanche: TVL, protocol rankings, token prices, and trading pairs.",
      examples: [
        "What is the current TVL on Avalanche?",
        "Show me the top DeFi protocols on Avalanche",
        "What is the price of AVAX?",
      ],
    },
    {
      id: "ecosystem-explorer",
      name: "Ecosystem Explorer",
      description: "Explore Avalanche L1 blockchains, subnets, and ecosystem data via Glacier API.",
      examples: [
        "How many L1 blockchains are active on Avalanche?",
        "List the latest subnets created on Avalanche",
      ],
    },
  ],
  defaultInputModes: ["text"],
  defaultOutputModes: ["text"],
};

// Serve the agent card
app.get("/.well-known/agent-card.json", (c) => {
  return c.json(agentCard);
});
```

### 2. Implement A2A Endpoints

```typescript
// A2A Guide endpoint - Receives natural language questions
app.post("/a2a/guide", async (c) => {
  try {
    const body = await c.req.json();
    const question = body.question || body.message || body.input;

    if (!question || typeof question !== "string") {
      return c.json({
        error: "Missing 'question' field",
        usage: {
          method: "POST",
          body: { question: "How do I build on Avalanche?" },
        },
      }, 400);
    }

    // Process the question using your knowledge base / LLM
    const answer = await processQuestion(question);

    return c.json({
      agent: "AvaBuilder Agent",
      skill: "avalanche-guide",
      question,
      answer,
      sources: answer.sources || [],
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    return c.json({ error: "Internal error processing question" }, 500);
  }
});

// A2A Analytics endpoint - Structured data requests
app.post("/a2a/analytics", async (c) => {
  try {
    const body = await c.req.json();
    const query = body.query || body.type;

    switch (query) {
      case "tvl":
        const tvl = await defiAPIs.getAvalancheTVL();
        return c.json({ type: "tvl", value: tvl, chain: "avalanche" });

      case "protocols":
        const protocols = await defiAPIs.getAvalancheDeFiProtocols();
        return c.json({ type: "protocols", data: protocols, count: protocols.length });

      case "price":
        const tokenId = body.tokenId || "avalanche-2";
        const price = await defiAPIs.getTokenPrice(tokenId);
        return c.json({ type: "price", tokenId, data: price });

      default:
        return c.json({
          error: "Unknown query type",
          availableQueries: ["tvl", "protocols", "price"],
        }, 400);
    }
  } catch (error) {
    return c.json({ error: "Analytics query failed" }, 500);
  }
});
```

### 3. Declare A2A in Registration

```json
{
  "services": [
    {
      "name": "A2A",
      "endpoint": "https://your-agent.com/.well-known/agent-card.json",
      "version": "0.3.0"
    }
  ]
}
```

---

## Client Side: Consuming Another Agent via A2A

### Step-by-Step: How Agent A Talks to Agent B

```typescript
/**
 * Complete A2A client flow:
 * 1. Discover agent from ERC-8004 registry
 * 2. Fetch agent card
 * 3. Understand capabilities
 * 4. Send request
 * 5. Process response
 */

// Step 1: Get agent metadata from registration.json
async function discoverAgent(registrationUrl: string) {
  const response = await fetch(registrationUrl, {
    signal: AbortSignal.timeout(10_000),
  });
  const metadata = await response.json();

  // Find A2A service
  const a2aService = metadata.services?.find(
    (s: { name: string }) => s.name === "A2A"
  );

  if (!a2aService) {
    throw new Error("Agent does not support A2A");
  }

  return {
    name: metadata.name,
    a2aEndpoint: a2aService.endpoint,
    a2aVersion: a2aService.version,
    x402Support: metadata.x402Support,
    capabilities: metadata.capabilities,
  };
}

// Step 2: Fetch and parse the agent card
async function getAgentCard(a2aEndpoint: string) {
  const response = await fetch(a2aEndpoint, {
    signal: AbortSignal.timeout(10_000),
  });
  return await response.json();
}

// Step 3: Ask the agent a question
async function askAgent(
  agentBaseUrl: string,
  question: string
): Promise<Record<string, unknown>> {
  const response = await fetch(`${agentBaseUrl}/a2a/guide`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ question }),
    signal: AbortSignal.timeout(30_000),
  });

  if (!response.ok) {
    throw new Error(`Agent returned ${response.status}`);
  }

  return await response.json();
}

// Step 4: Get structured data from the agent
async function queryAgentAnalytics(
  agentBaseUrl: string,
  query: string,
  params: Record<string, unknown> = {}
): Promise<Record<string, unknown>> {
  const response = await fetch(`${agentBaseUrl}/a2a/analytics`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query, ...params }),
    signal: AbortSignal.timeout(15_000),
  });

  return await response.json();
}
```

### Complete Example: Agent-to-Agent Conversation

```typescript
async function agentToAgentDemo() {
  // 1. Discover AvaBuilder Agent
  const agent = await discoverAgent(
    "https://avariskscan-defi-production.up.railway.app/registration.json"
  );
  console.log(`Found agent: ${agent.name}`);
  console.log(`A2A version: ${agent.a2aVersion}`);
  console.log(`Capabilities: ${agent.capabilities.join(", ")}`);

  // 2. Read its agent card to understand skills
  const card = await getAgentCard(agent.a2aEndpoint);
  console.log(`\nSkills available:`);
  for (const skill of card.skills) {
    console.log(`  - ${skill.name}: ${skill.description}`);
    console.log(`    Examples: ${skill.examples.join("; ")}`);
  }

  // 3. Ask a natural language question
  const guideResponse = await askAgent(
    "https://avariskscan-defi-production.up.railway.app",
    "How do I create an L1 blockchain on Avalanche?"
  );
  console.log(`\nQuestion: ${guideResponse.question}`);
  console.log(`Answer: ${guideResponse.answer}`);

  // 4. Get structured analytics data
  const tvlData = await queryAgentAnalytics(
    "https://avariskscan-defi-production.up.railway.app",
    "tvl"
  );
  console.log(`\nAvalanche TVL: $${tvlData.value}`);

  // 5. Get protocol rankings
  const protocols = await queryAgentAnalytics(
    "https://avariskscan-defi-production.up.railway.app",
    "protocols"
  );
  console.log(`Top protocols: ${protocols.count}`);

  // 6. Get token price
  const price = await queryAgentAnalytics(
    "https://avariskscan-defi-production.up.railway.app",
    "price",
    { tokenId: "avalanche-2" }
  );
  console.log(`AVAX price: $${(price.data as { usd: number })?.usd}`);
}

agentToAgentDemo().catch(console.error);
```

---

## Agent Card Specification (v0.3.0)

```
┌──────────────────────────────────────────────────────────────┐
│                   AGENT CARD STRUCTURE                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  {                                                           │
│    "name": string           // Agent display name            │
│    "description": string    // What the agent does           │
│    "url": string            // Agent's base URL              │
│    "version": "0.3.0"       // A2A protocol version          │
│                                                              │
│    "capabilities": {                                         │
│      "streaming": boolean   // Supports streaming responses  │
│      "pushNotifications": boolean  // Can push updates       │
│    }                                                         │
│                                                              │
│    "skills": [              // Array of skills               │
│      {                                                       │
│        "id": string         // Unique skill identifier       │
│        "name": string       // Human-readable name           │
│        "description": string // What this skill does         │
│        "examples": string[] // Example inputs                │
│      }                                                       │
│    ]                                                         │
│                                                              │
│    "defaultInputModes": ["text"]   // Accepted input types   │
│    "defaultOutputModes": ["text"]  // Output types           │
│  }                                                           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Best Practices for Agent Cards

| Field | Best Practice |
|-------|--------------|
| `name` | Same as `registration.json` name |
| `description` | Brief (1-2 sentences), actionable |
| `skills` | Each skill = one distinct capability |
| `examples` | 2-3 realistic questions per skill |
| `streaming` | Only `true` if you implement SSE/WebSocket |
| `version` | Use `"0.3.0"` (current A2A version) |

---

## Multi-Agent Workflow Example

Agents can chain together to solve complex tasks:

```
┌──────────────────────────────────────────────────────────────┐
│           MULTI-AGENT WORKFLOW: DeFi Research                │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  User: "Analyze the best DeFi opportunity on Avalanche"     │
│                                                              │
│  Orchestrator Agent                                          │
│  ├─ Step 1: Ask AvaBuilder Agent (A2A)                      │
│  │   └─ "What are the top DeFi protocols on Avalanche?"     │
│  │   └─ Response: Aave, Benqi, Trader Joe, GMX...           │
│  │                                                           │
│  ├─ Step 2: Ask AvaBuilder Agent (A2A)                      │
│  │   └─ "What is the TVL and 7d change for each?"           │
│  │   └─ Response: Protocol data with trends                 │
│  │                                                           │
│  ├─ Step 3: Ask AvaBuilder Agent (A2A)                      │
│  │   └─ "What DEX pairs have highest volume?"               │
│  │   └─ Response: Top 30 pairs by 24h volume                │
│  │                                                           │
│  ├─ Step 4: Ask Price Agent (A2A) [another agent]           │
│  │   └─ "What is the price trend for AVAX?"                 │
│  │   └─ Response: Price + 24h change                        │
│  │                                                           │
│  └─ Step 5: Synthesize & Present                            │
│      └─ Combine all data into actionable recommendation     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## A2A vs MCP: When to Use Each

| Feature | A2A | MCP |
|---------|-----|-----|
| **Communication** | Natural language | Structured JSON-RPC |
| **Discovery** | agent-card.json | tools/list |
| **Best for** | Open-ended questions, conversations | Specific tool calls, data retrieval |
| **Input** | Free-form text | Typed parameters with JSON Schema |
| **Output** | Free-form text/JSON | Structured tool results |
| **Use case** | "How do I build on Avalanche?" | `getAvalancheTVL()` |
| **Agent type** | Human-like interaction | Programmatic access |

### Recommendation

Implement **both** A2A and MCP:
- **A2A** for agents that want to have conversations and ask open-ended questions
- **MCP** for agents that want to call specific tools programmatically

This makes your agent accessible to the widest range of clients.

---

## Reputation Feedback After A2A Interaction

After interacting with another agent via A2A, give on-chain feedback:

```typescript
import { createWalletClient, http, parseAbi } from "viem";
import { avalanche } from "viem/chains";

const reputationAbi = parseAbi([
  "function giveFeedback(uint256 agentId, int128 value, uint8 valueDecimals, string tag1, string tag2, string endpoint, string feedbackURI, bytes32 feedbackHash) external",
]);

// Give positive feedback after successful A2A interaction
async function rateAgent(agentId: number, score: number) {
  const walletClient = createWalletClient({
    account: privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`),
    chain: avalanche,
    transport: http(),
  });

  await walletClient.writeContract({
    address: "0x8004BAa17C55a88189AE136b182e5fdA19dE9b63",
    abi: reputationAbi,
    functionName: "giveFeedback",
    args: [
      BigInt(agentId),
      BigInt(score),     // 0-100
      0,                 // decimals
      "starred",         // tag1
      "a2a",             // tag2 - indicates this was A2A interaction
      "",                // endpoint
      "",                // feedbackURI
      "0x0000000000000000000000000000000000000000000000000000000000000000",
    ],
  });

  console.log(`Rated agent #${agentId}: ${score}/100`);
}
```

---

*Guide created by Cyber Paisa based on real A2A implementation in AvaBuilder Agent (Agent #1686 on Avalanche Mainnet).*
