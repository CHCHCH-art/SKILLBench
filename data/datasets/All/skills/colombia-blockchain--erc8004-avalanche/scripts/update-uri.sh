#!/usr/bin/env bash
set -euo pipefail

# ERC-8004 Agent URI Update on Avalanche C-Chain
# Updates the metadata URI of an already registered agent.
# Use this to refresh metadata in Snowtrace and scanners without re-registering.
#
# Usage:
#   ./scripts/update-uri.sh <agent-id> <new-uri>
#   NETWORK=fuji ./scripts/update-uri.sh <agent-id> <new-uri>
#
# Examples:
#   ./scripts/update-uri.sh 1686 "https://myagent.up.railway.app/registration.json"
#   NETWORK=fuji ./scripts/update-uri.sh 15 "https://myagent.up.railway.app/registration.json"
#
# Why use this:
#   - After updating registration.json (description, image, services, capabilities)
#   - To force Snowtrace to refresh cached metadata
#   - To fix scanner warnings caused by stale metadata
#   - The on-chain call emits URIUpdated event, which scanners and explorers detect

NETWORK="${NETWORK:-mainnet}"

if [ "$NETWORK" = "fuji" ]; then
  RPC_URL="${AVALANCHE_RPC_URL:-https://api.avax-test.network/ext/bc/C/rpc}"
  IDENTITY_REGISTRY="0x8004A818BFB912233c491871b3d84c89A494BD9e"
  CHAIN_ID="43113"
  EXPLORER="https://testnet.snowtrace.io"
else
  RPC_URL="${AVALANCHE_RPC_URL:-https://api.avax.network/ext/bc/C/rpc}"
  IDENTITY_REGISTRY="0x8004A169FB4a3325136EB29fA0ceB6D2e539a432"
  CHAIN_ID="43114"
  EXPLORER="https://snowtrace.io"
fi

if [ -z "${PRIVATE_KEY:-}" ]; then
  echo "Error: PRIVATE_KEY environment variable is required"
  echo "  export PRIVATE_KEY=\"your-private-key\""
  exit 1
fi

AGENT_ID="${1:-}"
NEW_URI="${2:-}"

if [ -z "$AGENT_ID" ] || [ -z "$NEW_URI" ]; then
  echo "Usage: ./scripts/update-uri.sh <agent-id> <new-uri>"
  echo ""
  echo "Examples:"
  echo "  ./scripts/update-uri.sh 1686 \"https://myagent.up.railway.app/registration.json\""
  echo "  NETWORK=fuji ./scripts/update-uri.sh 15 \"https://myagent.up.railway.app/registration.json\""
  echo ""
  echo "This updates the on-chain metadata URI and forces scanners/Snowtrace to refresh."
  exit 1
fi

# Check if cast (Foundry) is available
if ! command -v cast &> /dev/null; then
  echo "Error: 'cast' (Foundry) is required. Install it with:"
  echo "  curl -L https://foundry.paradigm.xyz | bash && foundryup"
  exit 1
fi

echo ""
echo "=== ERC-8004 Agent URI Update ==="
echo "Network:   Avalanche $NETWORK (Chain ID: $CHAIN_ID)"
echo "Registry:  $IDENTITY_REGISTRY"
echo "Agent ID:  $AGENT_ID"
echo "New URI:   $NEW_URI"
echo ""

# Verify the caller owns the agent
WALLET_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY")
OWNER=$(cast call "$IDENTITY_REGISTRY" "ownerOf(uint256)(address)" "$AGENT_ID" --rpc-url "$RPC_URL" 2>/dev/null || echo "")

if [ -z "$OWNER" ]; then
  echo "Error: Agent #$AGENT_ID not found in registry"
  exit 1
fi

if [ "$(echo "$OWNER" | tr '[:upper:]' '[:lower:]')" != "$(echo "$WALLET_ADDRESS" | tr '[:upper:]' '[:lower:]')" ]; then
  echo "Error: You are not the owner of Agent #$AGENT_ID"
  echo "  Your wallet: $WALLET_ADDRESS"
  echo "  Agent owner: $OWNER"
  exit 1
fi

echo "Owner verified: $WALLET_ADDRESS"

# Show current URI
CURRENT_URI=$(cast call "$IDENTITY_REGISTRY" "tokenURI(uint256)(string)" "$AGENT_ID" --rpc-url "$RPC_URL" 2>/dev/null || echo "unknown")
echo "Current URI: $CURRENT_URI"
echo ""

# Verify new URI is accessible
echo "Verifying new URI is accessible..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$NEW_URI" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" != "200" ]; then
  echo "Warning: URI returned HTTP $HTTP_STATUS (expected 200)"
  echo "The URI should be publicly accessible before updating on-chain."
  read -p "Continue anyway? (y/n): " CONFIRM
  if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled."
    exit 0
  fi
else
  echo "URI accessible (HTTP 200)"
fi

echo ""
echo "Updating agent URI on-chain..."

TX_HASH=$(cast send "$IDENTITY_REGISTRY" \
  "setAgentURI(uint256,string)" "$AGENT_ID" "$NEW_URI" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --json | grep -o '"transactionHash":"[^"]*"' | cut -d'"' -f4)

echo "Transaction sent: $TX_HASH"
echo "Explorer: $EXPLORER/tx/$TX_HASH"

# Wait for confirmation
echo "Waiting for confirmation..."
sleep 5

RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json 2>/dev/null || echo "")

if [ -n "$RECEIPT" ]; then
  STATUS=$(echo "$RECEIPT" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  if [ "$STATUS" = "0x1" ]; then
    echo ""
    echo "=== URI Updated Successfully ==="
    echo "Agent #$AGENT_ID URI is now: $NEW_URI"
    echo "Transaction: $EXPLORER/tx/$TX_HASH"
    echo ""
    echo "Next steps:"
    echo "  1. Wait 5-10 minutes for scanners to refresh"
    echo "  2. Check Snowtrace: $EXPLORER/nft/$IDENTITY_REGISTRY/$AGENT_ID"
    echo "  3. Check scanner: https://8004scan.io"
    echo "  4. If Snowtrace still shows old data, click 'Refresh Metadata'"
  else
    echo ""
    echo "Error: Transaction reverted"
    echo "Check: $EXPLORER/tx/$TX_HASH"
  fi
else
  echo ""
  echo "Transaction submitted. Check status at:"
  echo "$EXPLORER/tx/$TX_HASH"
fi
