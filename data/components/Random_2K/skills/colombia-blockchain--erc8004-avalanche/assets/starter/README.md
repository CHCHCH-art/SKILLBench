# ERC-8004 Agent — Starter Template

Create your own AI agent with on-chain identity in 5 minutes.

---

## Prerequisites (What You Need First)

Before starting, make sure you have these installed on your computer:

| Tool | What is it? | How to install |
|------|-------------|----------------|
| **Node.js** (v18+) | Runs JavaScript/TypeScript code on your computer | [nodejs.org/en/download](https://nodejs.org/en/download) — download and run the installer |
| **Git** | Tracks changes in your code and uploads to GitHub | [git-scm.com/downloads](https://git-scm.com/downloads) — download and run the installer |
| **A code editor** | Where you write and edit code | [VS Code](https://code.visualstudio.com/) (free, recommended) |
| **A GitHub account** | Where your code lives online | [github.com](https://github.com/) — sign up for free |
| **A crypto wallet** | Needed to register your agent on-chain | [MetaMask](https://metamask.io/) — install the browser extension |

To verify Node.js and Git are installed, open your **Terminal** (Mac) or **Command Prompt** (Windows) and type:

```bash
node --version    # Should show v18 or higher
git --version     # Should show a version number
```

> **What is a Terminal?** It's the app where you type commands. On Mac: search "Terminal" in Spotlight. On Windows: search "Command Prompt" or "PowerShell" in Start.

---

## Quick Start

```bash
# 1. Install dependencies (downloads the libraries your agent needs)
npm install

# 2. Run locally (starts the agent on your computer)
npm run dev

# 3. Open in browser
open http://localhost:3000
```

Your agent is running! You should see the dashboard.

## Test Your Endpoints

```bash
# Dashboard (visual page)
curl http://localhost:3000/

# Health check
curl http://localhost:3000/api/health

# Registration metadata
curl http://localhost:3000/registration.json

# MCP — list available tools
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# MCP — call a tool
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":2,"params":{"name":"ping","arguments":{"message":"hello"}}}'
```

## Customize Your Agent

1. Edit `registration.json` — change name, description, capabilities
2. Edit `src/server.ts` — add your own MCP tools and API endpoints
3. Replace `public/agent.png` with your agent's image (recommended: 512x512 PNG)
4. Edit `dashboard.html` to customize the visual page

## Deploy to Railway

Railway is a hosting service that puts your agent online so anyone can access it.

1. Create a repository on [github.com](https://github.com/) and push your code:
   ```bash
   git init
   git add .
   git commit -m "My first ERC-8004 agent"
   git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git
   git push -u origin main
   ```
2. Go to [railway.app](https://railway.app) → sign up with GitHub → New Project → Deploy from GitHub
3. Select your repository. Railway auto-detects the Dockerfile and deploys
4. Get your public URL (e.g., `https://my-agent-production.up.railway.app`)
5. Update all `YOUR-DOMAIN` in `registration.json` with your Railway URL and push again

## Register On-Chain

This step gives your agent an official on-chain identity (like a digital ID card). The example below uses Avalanche Fuji testnet:

```bash
# Install Foundry (command-line tool for blockchain interaction)
curl -L https://foundry.paradigm.xyz | bash && foundryup

# Get test AVAX from faucet (free test tokens)
# Visit: https://faucet.avax.network

# Register on Fuji testnet
export PRIVATE_KEY="your-private-key"
cast send 0x8004A818BFB912233c491871b3d84c89A494BD9e \
  "register(string)" \
  "https://YOUR-RAILWAY-URL/registration.json" \
  --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
  --private-key $PRIVATE_KEY
```

> **Where do I get my private key?** In MetaMask: click the three dots → Account details → Show private key. **NEVER share this key with anyone.**

After registering, you'll get an `agentId`. Update `registration.json` with it and redeploy.

## Project Structure

```
├── src/server.ts          # Your agent's code (endpoints + MCP)
├── registration.json      # ERC-8004 metadata (name, services, capabilities)
├── dashboard.html         # Visual page shown at /
├── public/agent.png       # Your agent's image
├── package.json           # Dependencies (libraries your agent uses)
├── tsconfig.json          # TypeScript config
├── Dockerfile             # Tells Railway how to run your agent
├── railway.toml           # Railway settings
├── .env.example           # Environment variables template
└── .well-known/           # Domain verification
```

---

## Glossary

| Term | Simple explanation |
|------|--------------------|
| **Agent** | A program that runs online and can do tasks automatically (answer questions, provide data, etc.) |
| **Avalanche** | An EVM blockchain (like Ethereum but faster and cheaper). Currently the main chain for ERC-8004 |
| **AVAX** | The native token of Avalanche. You need a tiny amount to pay for registration fees |
| **Blockchain** | A public digital record that nobody can alter. Used here to give your agent a verified identity |
| **cast** | A command-line tool (from Foundry) to interact with blockchains |
| **curl** | A command to make web requests from the terminal. Like visiting a URL without a browser |
| **Dashboard** | The visual web page that shows your agent's info when someone visits its URL |
| **Deploy** | To put your code on a server so it's accessible to everyone on the internet |
| **Docker / Dockerfile** | A way to package your app so it runs the same everywhere. Railway uses it automatically |
| **Endpoint** | A URL that returns data. Example: `/api/health` returns if the agent is alive |
| **ERC-8004** | An Ethereum standard that defines how AI agents register and build reputation on any EVM chain |
| **Faucet** | A website that gives you free test tokens (test AVAX) for experimenting |
| **Foundry** | A set of tools for working with blockchains from the terminal |
| **Fuji** | Avalanche's test network. Use it to practice before going to mainnet (the real network) |
| **Git** | A tool that tracks changes in your code and lets you upload it to GitHub |
| **GitHub** | A website where developers store and share code |
| **Hono** | The web framework (library) used to build your agent's server |
| **JSON** | A text format for structured data. Example: `{"name": "My Agent", "active": true}` |
| **JSON-RPC** | A way for programs to communicate using JSON messages (used by MCP) |
| **Localhost** | Your own computer acting as a server. `localhost:3000` = your machine, port 3000 |
| **Mainnet** | The real/production network where transactions cost real tokens |
| **MCP** | Model Context Protocol — a standard way for AI agents to expose tools that other agents can use |
| **MetaMask** | A popular crypto wallet (browser extension) for managing your blockchain accounts |
| **NFT** | A unique digital token. Your agent's on-chain identity is an NFT (ERC-721) |
| **Node.js** | A program that lets you run JavaScript/TypeScript on your computer (not just in browsers) |
| **npm** | Node Package Manager — downloads and manages libraries for your project |
| **On-chain** | Recorded on the blockchain. Your agent's registration is on-chain |
| **Private key** | A secret password that controls your blockchain wallet. **Never share it** |
| **Railway** | A hosting platform that deploys your code to the internet automatically |
| **registration.json** | The file that describes your agent (name, description, services, image) |
| **Repository (repo)** | A folder of code tracked by Git, usually hosted on GitHub |
| **RPC** | Remote Procedure Call — the URL you use to talk to the blockchain network |
| **Server** | A program running 24/7 that responds to requests from the internet |
| **Snowtrace** | Avalanche's block explorer — a website to see transactions, contracts, and agents |
| **Terminal** | The app where you type commands. Mac: Terminal. Windows: Command Prompt / PowerShell |
| **Token** | A digital asset on a blockchain (AVAX is a token, your agent's NFT is a token) |
| **TypeScript** | A programming language (JavaScript with types). Your agent's code is in TypeScript |
| **URI / URL** | A web address. Example: `https://my-agent.com/registration.json` |
| **Wallet** | A digital account on a blockchain, identified by an address (like a bank account number) |

---

## Learn More

- [ERC-8004 Spec](https://eips.ethereum.org/EIPS/eip-8004)
- [8004.org](https://www.8004.org)
- [8004scan.io](https://8004scan.io)
- [Colombia-Blockchain/agent-skills](https://github.com/Colombia-Blockchain/agent-skills)
