#!/usr/bin/env bash
set -euo pipefail

# Check AvaRisk DeFi agent registration on Fuji

echo "=== Verificando AvaRisk DeFi en Avalanche Fuji ==="
echo ""

# Agent details
WALLET="0x29a45b03F07D1207f2e3ca34c38e7BE5458CE71a"
AGENT_URL="https://avariskscan-defi-production.up.railway.app"
TX_HASH="0x2967a4574eb72b6742c72a1fb815a958492c392663e7db9c56b671afb6e7f02e"

echo "1. Verificando endpoints públicos..."
echo ""

# Health check
echo "   ✓ Health check:"
curl -s "$AGENT_URL/" | jq -r '.status, .agent' | head -2

echo ""
echo "   ✓ Registration JSON:"
curl -s "$AGENT_URL/registration.json" | jq -r '.name'

echo ""
echo "   ✓ A2A Agent Card:"
curl -s "$AGENT_URL/.well-known/agent-card.json" | jq -r '.name'

echo ""
echo "2. Verificando transacción de registro..."
echo "   TX: $TX_HASH"
echo "   Explorer: https://testnet.snowtrace.io/tx/$TX_HASH"

echo ""
echo "3. Wallet del agente:"
echo "   Address: $WALLET"
echo "   Explorer: https://testnet.snowtrace.io/address/$WALLET"

echo ""
echo "4. Scanner ERC-8004:"
echo "   URL: https://www.erc-8004scan.xyz/scanner"
echo "   Busca: AvaRisk DeFi o $WALLET"

echo ""
echo "✅ Verificación completada"
