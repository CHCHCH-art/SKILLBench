/**
 * ERC-8004 Agent — Starter Template
 *
 * This is a minimal but complete ERC-8004 agent ready to deploy on any EVM chain.
 * It includes: dashboard, health check, registration metadata, A2A card, and MCP server.
 *
 * To run locally:   npm run dev
 * To build:         npm run build
 * To start prod:    npm start
 *
 * After deploying to Railway, register on-chain with:
 *   cast send 0x8004A818BFB912233c491871b3d84c89A494BD9e \
 *     "register(string)" "https://YOUR-DOMAIN/registration.json" \
 *     --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
 *     --private-key $PRIVATE_KEY
 */

import "dotenv/config";
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, extname } from "node:path";
import { Hono } from "hono";
import { serve } from "@hono/node-server";
import { cors } from "hono/cors";

// ---------- Setup ----------

const __dirname = dirname(fileURLToPath(import.meta.url));

// Load registration.json at startup
const registration = JSON.parse(
  readFileSync(join(__dirname, "..", "registration.json"), "utf-8")
);

const app = new Hono();

// Version — change this when you update your agent
const VERSION = "1.0.0";

// ---------- Middleware ----------

// CORS — allows browsers and other agents to call your endpoints
app.use(
  "/*",
  cors({
    origin: "*",
    allowMethods: ["GET", "POST", "OPTIONS"],
    allowHeaders: ["Content-Type"],
  })
);

// ============================================================
// FREE PUBLIC ENDPOINTS
// These are the minimum endpoints every ERC-8004 agent needs.
// ============================================================

// 1. DASHBOARD — Visual page at root URL
//    This is what users see when they click your agent in the scanner.
//    IMPORTANT: Always serve HTML here, never raw JSON.
app.get("/", (c) => {
  try {
    const html = readFileSync(join(__dirname, "..", "dashboard.html"), "utf-8");
    return c.html(html);
  } catch {
    return c.text("Agent is running. Dashboard not found.", 200);
  }
});

// 2. HEALTH CHECK — JSON endpoint for Railway and monitoring
//    Railway uses this to know if your agent is alive.
app.get("/api/health", (c) => {
  return c.json({
    status: "ok",
    agent: registration.name,
    version: VERSION,
    timestamp: new Date().toISOString(),
  });
});

// 3. REGISTRATION.JSON — Your agent's ERC-8004 metadata
//    Scanners and other agents read this to discover your capabilities.
app.get("/registration.json", (c) => {
  return c.json(registration, 200, {
    "Content-Type": "application/json",
  });
});

// 4. A2A AGENT CARD — Agent-to-Agent discovery
//    Other agents use this endpoint to understand what your agent can do.
app.get("/.well-known/agent-card.json", (c) => {
  return c.json(registration, 200, {
    "Content-Type": "application/json",
  });
});

// 5. DOMAIN VERIFICATION — Proves you own this domain
//    Scanners check this to verify your agent is legitimate.
app.get("/.well-known/agent-registration.json", (c) => {
  try {
    const verification = readFileSync(
      join(__dirname, "..", ".well-known", "agent-registration.json"),
      "utf-8"
    );
    return c.json(JSON.parse(verification), 200, {
      "Content-Type": "application/json",
    });
  } catch {
    return c.json({ error: "Verification file not found" }, 404);
  }
});

// 6. STATIC FILES — Serve your agent's image and other files
//    Your agent image URL in registration.json points here.
app.get("/public/:filename", (c) => {
  const filename = c.req.param("filename");
  const filePath = join(__dirname, "..", "public", filename);

  if (!existsSync(filePath)) {
    return c.json({ error: "File not found" }, 404);
  }

  const ext = extname(filename).toLowerCase();
  const mimeTypes: Record<string, string> = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
    ".webp": "image/webp",
  };

  const contentType = mimeTypes[ext] || "application/octet-stream";
  const file = readFileSync(filePath);

  return new Response(file, {
    headers: {
      "Content-Type": contentType,
      "Cache-Control": "public, max-age=86400",
    },
  });
});

// ============================================================
// MCP SERVER (Model Context Protocol)
//
// MCP lets other AI agents discover and use your agent's tools
// programmatically via JSON-RPC.
//
// How it works:
//   1. Agent calls "initialize" to connect
//   2. Agent calls "tools/list" to see what tools you offer
//   3. Agent calls "tools/call" to use a specific tool
//
// To add your own tools:
//   1. Add a tool definition to MCP_TOOLS array
//   2. Add a case to the switch in "tools/call" handler
// ============================================================

// Define your MCP tools here.
// Each tool needs: name, description, and inputSchema (JSON Schema).
const MCP_TOOLS = [
  {
    name: "get_agent_info",
    description: "Get information about this agent: name, version, capabilities, and services",
    inputSchema: {
      type: "object",
      properties: {},
      required: [],
    },
  },
  {
    name: "ping",
    description: "Check if this agent is alive. Returns pong with current timestamp",
    inputSchema: {
      type: "object",
      properties: {
        message: {
          type: "string",
          description: "Optional message to echo back",
        },
      },
      required: [],
    },
  },
  // ---------------------------------------------------
  // ADD YOUR OWN TOOLS HERE. Example:
  // ---------------------------------------------------
  // {
  //   name: "get_weather",
  //   description: "Get current weather for a city",
  //   inputSchema: {
  //     type: "object",
  //     properties: {
  //       city: { type: "string", description: "City name" },
  //     },
  //     required: ["city"],
  //   },
  // },
];

// MCP endpoint — handles all JSON-RPC requests
app.post("/mcp", async (c) => {
  try {
    const body = await c.req.json();
    const { method, id, params } = body;

    // Helper to return a successful JSON-RPC response
    const rpcOk = (result: unknown) =>
      c.json({ jsonrpc: "2.0", id, result });

    // Helper to return an error JSON-RPC response
    const rpcErr = (code: number, message: string) =>
      c.json({ jsonrpc: "2.0", id, error: { code, message } });

    // --- Method: initialize ---
    // The first call an MCP client makes. Returns server info.
    if (method === "initialize") {
      return rpcOk({
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: {
          name: registration.name + " MCP",
          version: VERSION,
        },
      });
    }

    // --- Method: tools/list ---
    // Returns all available tools so the client knows what it can call.
    if (method === "tools/list") {
      return rpcOk({ tools: MCP_TOOLS });
    }

    // --- Method: tools/call ---
    // Executes a specific tool by name with the given arguments.
    if (method === "tools/call") {
      const toolName = params?.name;
      const args = params?.arguments || {};

      let result: unknown;

      switch (toolName) {
        case "get_agent_info": {
          result = {
            name: registration.name,
            description: registration.description,
            version: VERSION,
            capabilities: registration.capabilities,
            services: registration.services?.map((s: { name: string; endpoint: string }) => s.name),
            active: registration.active,
          };
          break;
        }

        case "ping": {
          result = {
            pong: true,
            message: args.message || "Hello from " + registration.name,
            timestamp: new Date().toISOString(),
          };
          break;
        }

        // ---------------------------------------------------
        // ADD YOUR OWN TOOL HANDLERS HERE. Example:
        // ---------------------------------------------------
        // case "get_weather": {
        //   const city = args.city as string;
        //   // Call a weather API, process data, etc.
        //   result = { city, temperature: "22C", condition: "sunny" };
        //   break;
        // }

        default:
          return rpcErr(-32601, `Tool not found: ${toolName}`);
      }

      // Return tool result in MCP format
      return rpcOk({
        content: [{ type: "text", text: JSON.stringify(result) }],
      });
    }

    // Unknown method
    return rpcErr(-32601, `Method not supported: ${method}`);
  } catch {
    return c.json(
      { jsonrpc: "2.0", id: null, error: { code: -32603, message: "Internal error" } },
      500
    );
  }
});

// ============================================================
// ADD YOUR OWN ENDPOINTS HERE
//
// Examples:
//   app.get("/api/data", async (c) => { ... });
//   app.post("/api/analyze", async (c) => { ... });
//
// For x402 paid endpoints, see the x402-guide.md in the skill docs.
// ============================================================

// ============================================================
// START SERVER
// ============================================================

const port = Number(process.env.PORT) || 3000;

serve({ fetch: app.fetch, port }, (info) => {
  console.log("");
  console.log(`  ${registration.name} v${VERSION}`);
  console.log(`  http://localhost:${info.port}`);
  console.log("");
  console.log("  Endpoints:");
  console.log(`  GET  /                        Dashboard`);
  console.log(`  GET  /api/health              Health check`);
  console.log(`  GET  /registration.json       ERC-8004 metadata`);
  console.log(`  GET  /.well-known/agent-card  A2A agent card`);
  console.log(`  POST /mcp                     MCP server (${MCP_TOOLS.length} tools)`);
  console.log("");
});
