#!/bin/bash

# Deploy Donation Contract to Devnet
# Usage: ./scripts/deploy-devnet.sh

set -e

echo "🚀 Deploying Donation Contract to Devnet..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Solana CLI is installed
if ! command -v solana &> /dev/null; then
    echo "❌ Solana CLI is not installed. Please install it first."
    exit 1
fi

# Check if Anchor CLI is installed
if ! command -v anchor &> /dev/null; then
    echo "❌ Anchor CLI is not installed. Please install it first."
    exit 1
fi

echo -e "${BLUE}📋 Pre-deployment checks...${NC}"

# Set Solana to devnet
echo "🌐 Setting Solana cluster to devnet..."
solana config set --url devnet

# Check wallet balance
BALANCE=$(solana balance)
echo -e "${YELLOW}💰 Wallet balance: $BALANCE${NC}"

# Check if balance is sufficient (need at least 2 SOL for deployment)
MIN_BALANCE=2.0
CURRENT_BALANCE=$(echo $BALANCE | awk '{print $1}')

if (( $(echo "$CURRENT_BALANCE < $MIN_BALANCE" | bc -l) )); then
    echo -e "${YELLOW}⚠️  Low balance detected. Requesting airdrop...${NC}"
    solana airdrop 2
    sleep 5
    BALANCE=$(solana balance)
    echo -e "${GREEN}✅ New balance: $BALANCE${NC}"
fi

echo ""
echo -e "${BLUE}🔨 Building program...${NC}"
anchor build

echo ""
echo -e "${BLUE}📦 Deploying program...${NC}"
PROGRAM_ID=$(anchor deploy --provider.cluster devnet 2>&1 | grep "Program Id:" | awk '{print $3}')

if [ -z "$PROGRAM_ID" ]; then
    echo "❌ Deployment failed"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Deployment successful!${NC}"
echo -e "${GREEN}📍 Program ID: $PROGRAM_ID${NC}"

# Save program ID to file
echo $PROGRAM_ID > .deploy/devnet-program-id.txt
mkdir -p .deploy
echo $PROGRAM_ID > .deploy/devnet-program-id.txt
echo "$(date)" >> .deploy/devnet-program-id.txt

echo ""
echo -e "${YELLOW}⚠️  Important: Update the program ID in lib.rs:${NC}"
echo "   declare_id!(\"$PROGRAM_ID\");"
echo ""

# Run tests if requested
read -p "Do you want to run tests? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}🧪 Running tests...${NC}"
    anchor test --skip-deploy
fi

echo ""
echo -e "${GREEN}✨ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Update the program ID in programs/donation/src/lib.rs"
echo "2. Rebuild: anchor build"
echo "3. Redeploy: anchor deploy --provider.cluster devnet"
echo "4. Initialize the vault using the client SDK"
echo ""
