# MCP: Model Context Protocol for ERC-8004 Agents

Complete implementation guide for MCP (Model Context Protocol). MCP enables programmatic, structured access to your agent's capabilities via JSON-RPC, allowing other AI agents to discover and invoke your tools without human intervention.

---

## How MCP Works

```
┌──────────────────────────────────────────────────────────────────┐
│                      MCP PROTOCOL FLOW                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CLIENT AGENT                         MCP SERVER (Your Agent)    │
│  ─────────────                        ───────────────────────    │
│                                                                  │
│  1. POST /mcp                                                    │
│     { method: "initialize" }  ────▶  Returns server info         │
│                                      + supported capabilities    │
│                                                                  │
│  2. POST /mcp                                                    │
│     { method: "tools/list" }  ────▶  Returns all available       │
│                                      tools with JSON Schemas     │
│                                                                  │
│  3. POST /mcp                                                    │
│     { method: "tools/call",                                      │
│       params: {                                                  │
│         name: "getAvalancheTVL",                                │
│         arguments: {}          ────▶  Executes the tool          │
│       }                               Returns structured data    │
│     }                                                            │
│                                                                  │
│  Client can call any tool from step 2, as many times as needed  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Server Side: Implementing MCP

### 1. JSON-RPC Handler

MCP uses JSON-RPC 2.0. Every request has `jsonrpc`, `method`, `id`, and optionally `params`.

```typescript
import { Hono } from "hono";

const app = new Hono();

// MCP endpoint - handles all JSON-RPC methods
app.post("/mcp", async (c) => {
  try {
    const body = await c.req.json();
    const { jsonrpc, method, id, params } = body;

    // Validate JSON-RPC format
    if (jsonrpc !== "2.0") {
      return c.json({
        jsonrpc: "2.0",
        id,
        error: { code: -32600, message: "Invalid JSON-RPC version" },
      });
    }

    // Route to handler based on method
    switch (method) {
      case "initialize":
        return c.json(handleInitialize(id));

      case "tools/list":
        return c.json(handleToolsList(id));

      case "tools/call":
        return c.json(await handleToolsCall(id, params));

      default:
        return c.json({
          jsonrpc: "2.0",
          id,
          error: { code: -32601, message: `Method not found: ${method}` },
        });
    }
  } catch (error) {
    return c.json({
      jsonrpc: "2.0",
      id: null,
      error: { code: -32700, message: "Parse error" },
    });
  }
});
```

### 2. Initialize Handler

Returns server metadata and capabilities.

```typescript
function handleInitialize(id: number | string) {
  return {
    jsonrpc: "2.0",
    id,
    result: {
      protocolVersion: "2025-06-18",
      serverInfo: {
        name: "AvaBuilder Agent MCP",
        version: "2.1.0",
      },
      capabilities: {
        tools: { listChanged: false },
      },
    },
  };
}
```

### 3. Tools List Handler

Returns ALL available tools with complete JSON Schemas. This is how other agents discover what you can do.

```typescript
function handleToolsList(id: number | string) {
  return {
    jsonrpc: "2.0",
    id,
    result: {
      tools: [
        // Tool 1: Get AVAX Price
        {
          name: "getAvalanchePrice",
          description: "Get current AVAX price in USD with 24h change percentage from CoinGecko",
          inputSchema: {
            type: "object",
            properties: {},
            required: [],
          },
        },

        // Tool 2: Get Avalanche TVL
        {
          name: "getAvalancheTVL",
          description: "Get total value locked (TVL) across all DeFi protocols on Avalanche from DeFiLlama",
          inputSchema: {
            type: "object",
            properties: {},
            required: [],
          },
        },

        // Tool 3: Get DeFi Protocols
        {
          name: "getAvalancheProtocols",
          description: "Get top 50 DeFi protocols on Avalanche sorted by TVL, with category and 1d/7d change",
          inputSchema: {
            type: "object",
            properties: {},
            required: [],
          },
        },

        // Tool 4: Get Token Price (with parameter)
        {
          name: "getTokenPrice",
          description: "Get price for any token by CoinGecko ID (e.g., 'bitcoin', 'ethereum', 'avalanche-2')",
          inputSchema: {
            type: "object",
            properties: {
              tokenId: {
                type: "string",
                description: "CoinGecko token ID (e.g., 'avalanche-2', 'bitcoin', 'ethereum')",
              },
            },
            required: ["tokenId"],
          },
        },

        // Tool 5: Search Tokens
        {
          name: "searchToken",
          description: "Search for tokens by name or symbol on CoinGecko. Returns top 10 matches.",
          inputSchema: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "Search query (token name or symbol, e.g., 'avalanche' or 'AVAX')",
              },
            },
            required: ["query"],
          },
        },

        // Tool 6: Get DEX Pairs
        {
          name: "getDexPairs",
          description: "Get trading pairs for a token on Avalanche DEXs from DEX Screener",
          inputSchema: {
            type: "object",
            properties: {
              tokenAddress: {
                type: "string",
                description: "Token contract address on Avalanche C-Chain (0x format)",
              },
            },
            required: ["tokenAddress"],
          },
        },

        // Tool 7: Get Top DEX Pairs
        {
          name: "getTopDexPairs",
          description: "Get top 30 trading pairs on Avalanche DEXs by 24h volume",
          inputSchema: {
            type: "object",
            properties: {},
            required: [],
          },
        },

        // Tool 8: Get Avalanche L1s
        {
          name: "getAvalancheL1s",
          description: "Get all L1 blockchains (subnets) on Avalanche via Glacier API with pagination",
          inputSchema: {
            type: "object",
            properties: {},
            required: [],
          },
        },

        // Tool 9: Ask Avalanche Guide
        {
          name: "askGuide",
          description: "Ask a technical question about building on Avalanche. Uses AI + 128K lines of official documentation to synthesize answers.",
          inputSchema: {
            type: "object",
            properties: {
              question: {
                type: "string",
                description: "Technical question about Avalanche (e.g., 'How to deploy an ERC-20 token?')",
              },
            },
            required: ["question"],
          },
        },

        // Tool 10: Get Build Templates
        {
          name: "getTemplates",
          description: "Get step-by-step build templates for Avalanche projects (L1 chain, ERC-20, DEX, bridge, etc.)",
          inputSchema: {
            type: "object",
            properties: {
              templateId: {
                type: "string",
                description: "Optional template ID to get a specific template. Omit to list all available templates.",
              },
            },
            required: [],
          },
        },
      ],
    },
  };
}
```

### 4. Tools Call Handler

Executes a tool and returns the result.

```typescript
async function handleToolsCall(
  id: number | string,
  params: { name: string; arguments?: Record<string, unknown> }
) {
  const { name, arguments: args = {} } = params;

  try {
    let result: unknown;

    switch (name) {
      case "getAvalanchePrice": {
        const price = await defiAPIs.getAvalanchePrice();
        result = price || { error: "Price unavailable" };
        break;
      }

      case "getAvalancheTVL": {
        const tvl = await defiAPIs.getAvalancheTVL();
        result = { tvl, formatted: formatTVL(tvl), chain: "avalanche" };
        break;
      }

      case "getAvalancheProtocols": {
        const protocols = await defiAPIs.getAvalancheDeFiProtocols();
        result = { protocols, count: protocols.length };
        break;
      }

      case "getTokenPrice": {
        const tokenId = args.tokenId as string;
        if (!tokenId) {
          return errorResponse(id, "Missing required parameter: tokenId");
        }
        const price = await defiAPIs.getTokenPrice(tokenId);
        result = price || { error: `Price not found for ${tokenId}` };
        break;
      }

      case "searchToken": {
        const query = args.query as string;
        if (!query) {
          return errorResponse(id, "Missing required parameter: query");
        }
        const results = await defiAPIs.searchToken(query);
        result = { results, count: results.length };
        break;
      }

      case "getDexPairs": {
        const address = args.tokenAddress as string;
        if (!address) {
          return errorResponse(id, "Missing required parameter: tokenAddress");
        }
        const pairs = await defiAPIs.getDexPairs(address);
        result = { pairs, count: pairs.length };
        break;
      }

      case "getTopDexPairs": {
        const pairs = await defiAPIs.getAvalancheTopPairs();
        result = { pairs, count: pairs.length };
        break;
      }

      case "getAvalancheL1s": {
        const l1s = await defiAPIs.getAvalancheL1s();
        result = { l1s: l1s.slice(0, 20), totalCount: l1s.length };
        break;
      }

      case "askGuide": {
        const question = args.question as string;
        if (!question) {
          return errorResponse(id, "Missing required parameter: question");
        }
        const answer = await avalancheGuide.askQuestion(question);
        result = answer;
        break;
      }

      case "getTemplates": {
        const templateId = args.templateId as string | undefined;
        if (templateId) {
          const template = await avalancheGuide.getTemplate(templateId);
          result = template || { error: `Template ${templateId} not found` };
        } else {
          const templates = await avalancheGuide.getTemplates();
          result = { templates, count: templates.length };
        }
        break;
      }

      default:
        return {
          jsonrpc: "2.0",
          id,
          error: { code: -32601, message: `Unknown tool: ${name}` },
        };
    }

    return {
      jsonrpc: "2.0",
      id,
      result: {
        content: [
          {
            type: "text",
            text: JSON.stringify(result, null, 2),
          },
        ],
      },
    };
  } catch (error) {
    return {
      jsonrpc: "2.0",
      id,
      error: {
        code: -32000,
        message: `Tool execution failed: ${(error as Error).message}`,
      },
    };
  }
}

function errorResponse(id: number | string, message: string) {
  return {
    jsonrpc: "2.0",
    id,
    error: { code: -32602, message },
  };
}
```

---

## Client Side: Consuming MCP Tools

### Step-by-Step: How Another Agent Uses Your MCP

```typescript
/**
 * MCP Client - Discovers and calls tools on another agent's MCP server
 */
class MCPClient {
  private baseUrl: string;

  constructor(mcpEndpoint: string) {
    this.baseUrl = mcpEndpoint;
  }

  // Send JSON-RPC request
  private async rpc(method: string, params?: unknown): Promise<unknown> {
    const response = await fetch(this.baseUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method,
        params,
        id: Date.now(),
      }),
      signal: AbortSignal.timeout(30_000),
    });

    const data = await response.json();

    if (data.error) {
      throw new Error(`MCP Error: ${data.error.message}`);
    }

    return data.result;
  }

  // Step 1: Initialize connection
  async initialize() {
    const result = await this.rpc("initialize") as {
      protocolVersion: string;
      serverInfo: { name: string; version: string };
    };
    console.log(`Connected to: ${result.serverInfo.name} v${result.serverInfo.version}`);
    return result;
  }

  // Step 2: List available tools
  async listTools() {
    const result = await this.rpc("tools/list") as {
      tools: Array<{
        name: string;
        description: string;
        inputSchema: Record<string, unknown>;
      }>;
    };
    return result.tools;
  }

  // Step 3: Call a specific tool
  async callTool(name: string, args: Record<string, unknown> = {}) {
    const result = await this.rpc("tools/call", { name, arguments: args });
    return result;
  }
}
```

### Complete Example: Automated Tool Discovery & Invocation

```typescript
async function mcpClientDemo() {
  // Connect to AvaBuilder Agent's MCP server
  const client = new MCPClient(
    "https://avariskscan-defi-production.up.railway.app/mcp"
  );

  // 1. Initialize
  const serverInfo = await client.initialize();
  console.log("Server:", serverInfo);

  // 2. Discover all tools
  const tools = await client.listTools();
  console.log(`\nAvailable tools (${tools.length}):`);
  for (const tool of tools) {
    console.log(`  ${tool.name}: ${tool.description}`);
    if (Object.keys(tool.inputSchema.properties || {}).length > 0) {
      console.log(`    Params: ${JSON.stringify(tool.inputSchema.properties)}`);
    }
  }

  // 3. Call tools
  console.log("\n--- Calling tools ---\n");

  // Get AVAX price
  const price = await client.callTool("getAvalanchePrice");
  console.log("AVAX Price:", price);

  // Get TVL
  const tvl = await client.callTool("getAvalancheTVL");
  console.log("TVL:", tvl);

  // Get specific token price
  const btcPrice = await client.callTool("getTokenPrice", {
    tokenId: "bitcoin",
  });
  console.log("BTC Price:", btcPrice);

  // Search for a token
  const search = await client.callTool("searchToken", {
    query: "joe",
  });
  console.log("Search results:", search);

  // Ask the guide
  const guide = await client.callTool("askGuide", {
    question: "How do I create a subnet on Avalanche?",
  });
  console.log("Guide answer:", guide);

  // Get build templates
  const templates = await client.callTool("getTemplates");
  console.log("Templates:", templates);
}

mcpClientDemo().catch(console.error);
```

---

## Tool Design Best Practices

### Input Schema Design

```
┌──────────────────────────────────────────────────────────────┐
│                 TOOL INPUT SCHEMA RULES                     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Always use JSON Schema format                           │
│     { type: "object", properties: {...}, required: [...] }  │
│                                                              │
│  2. Every parameter needs:                                   │
│     - type (string, number, boolean, array, object)         │
│     - description (what this parameter does)                │
│                                                              │
│  3. Mark required parameters in the "required" array        │
│                                                              │
│  4. Use descriptive examples in descriptions:               │
│     "CoinGecko token ID (e.g., 'bitcoin', 'avalanche-2')"  │
│                                                              │
│  5. Validate inputs in your handler:                        │
│     - Check required fields exist                           │
│     - Validate types and formats                            │
│     - Return clear error messages                           │
│                                                              │
│  6. Keep parameters minimal:                                │
│     - Don't require what you can default                    │
│     - Use optional params for advanced features             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Tool Naming Conventions

| Convention | Example | Description |
|-----------|---------|-------------|
| `get*` | `getAvalancheTVL` | Read-only data retrieval |
| `search*` | `searchToken` | Search/query operations |
| `ask*` | `askGuide` | NLP/AI-powered questions |
| `create*` | `createReport` | Generate new content |
| `analyze*` | `analyzeToken` | Complex analysis |

### Response Format

Always return results in the MCP content format:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"tvl\": 1234567890, \"formatted\": \"$1.23B\"}"
      }
    ]
  }
}
```

---

## Testing Your MCP Server

### Using curl

```bash
# 1. Initialize
curl -s -X POST https://your-agent.com/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1}' | jq .

# 2. List tools
curl -s -X POST https://your-agent.com/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":2}' | jq .

# 3. Call a tool (no parameters)
curl -s -X POST https://your-agent.com/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":3,"params":{"name":"getAvalancheTVL","arguments":{}}}' | jq .

# 4. Call a tool (with parameters)
curl -s -X POST https://your-agent.com/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":4,"params":{"name":"getTokenPrice","arguments":{"tokenId":"avalanche-2"}}}' | jq .

# 5. Test error handling (unknown tool)
curl -s -X POST https://your-agent.com/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":5,"params":{"name":"nonExistentTool","arguments":{}}}' | jq .

# 6. Test error handling (missing required param)
curl -s -X POST https://your-agent.com/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":6,"params":{"name":"getTokenPrice","arguments":{}}}' | jq .
```

### Expected Responses

```
Initialize:  → protocolVersion, serverInfo
tools/list:  → Array of tools with schemas
tools/call:  → { content: [{ type: "text", text: "..." }] }
Unknown:     → { error: { code: -32601, message: "..." } }
Bad params:  → { error: { code: -32602, message: "..." } }
```

---

## JSON-RPC Error Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| `-32700` | Parse error | Invalid JSON received |
| `-32600` | Invalid request | Missing jsonrpc field or wrong version |
| `-32601` | Method not found | Unknown method or tool name |
| `-32602` | Invalid params | Missing required parameter |
| `-32000` | Server error | Tool execution failed |

---

## Registration: Declaring MCP Support

In your `registration.json`:

```json
{
  "services": [
    {
      "name": "MCP",
      "endpoint": "https://your-agent.com/mcp",
      "version": "2025-06-18"
    }
  ],
  "capabilities": [
    "tool_interaction/api_schema_understanding",
    "tool_interaction/workflow_automation"
  ]
}
```

**Important checklist before declaring MCP**:
- [ ] `/mcp` endpoint accepts POST requests
- [ ] Handles `initialize`, `tools/list`, `tools/call` methods
- [ ] Each tool has a complete `inputSchema` with JSON Schema
- [ ] Required parameters are validated and return clear errors
- [ ] Unknown tools return `-32601` error
- [ ] All tools are tested and return valid data

---

## MCP + x402 Integration

You can combine MCP with x402 to have some tools free and some paid:

```typescript
// In your tools/call handler
case "premiumAnalysis": {
  // Check for payment header
  const paymentHeader = c.req.header("X-PAYMENT");
  if (!paymentHeader) {
    return {
      jsonrpc: "2.0",
      id,
      error: {
        code: 402,
        message: "Payment required",
        data: {
          amount: "10000",
          asset: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
          recipient: "0xYourWallet",
          network: "avalanche",
        },
      },
    };
  }
  // Verify payment and serve premium tool
  break;
}
```

---

*Guide created by Cyber Paisa based on real MCP implementation in AvaBuilder Agent (10 tools, full JSON Schemas, tested on Avalanche Mainnet).*
