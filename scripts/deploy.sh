#!/bin/bash

# Deployment Script for Solana Donation Contract
# Usage: ./scripts/deploy.sh [devnet|mainnet-beta|localnet]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER=${1:-devnet}
PROGRAM_NAME="donation"

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Solana Donation Contract - Deployment Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Validate cluster
if [[ ! "$CLUSTER" =~ ^(devnet|mainnet-beta|localnet)$ ]]; then
    echo -e "${RED}✗ Invalid cluster: $CLUSTER${NC}"
    echo -e "${YELLOW}Usage: $0 [devnet|mainnet-beta|localnet]${NC}"
    exit 1
fi

# Warning for mainnet
if [ "$CLUSTER" = "mainnet-beta" ]; then
    echo -e "${RED}⚠️  WARNING: You are deploying to MAINNET${NC}"
    echo -e "${YELLOW}This will use REAL SOL and deploy to production!${NC}"
    read -p "Are you absolutely sure? (type 'yes' to continue): " confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Deployment cancelled${NC}"
        exit 0
    fi
fi

echo -e "${BLUE}Target Cluster:${NC} $CLUSTER"
echo ""

# Step 1: Check environment
echo -e "${YELLOW}[1/7] Checking environment...${NC}"

if ! command -v solana &> /dev/null; then
    echo -e "${RED}✗ Solana CLI not found${NC}"
    exit 1
fi

if ! command -v anchor &> /dev/null; then
    echo -e "${RED}✗ Anchor CLI not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Environment OK${NC}"
echo ""

# Step 2: Configure Solana CLI
echo -e "${YELLOW}[2/7] Configuring Solana CLI...${NC}"
solana config set --url $CLUSTER
echo -e "${GREEN}✓ Configured for $CLUSTER${NC}"
echo ""

# Step 3: Check wallet
echo -e "${YELLOW}[3/7] Checking wallet...${NC}"
WALLET=$(solana address)
BALANCE=$(solana balance --lamports | awk '{print $1}')

echo -e "${BLUE}Wallet:${NC} $WALLET"
echo -e "${BLUE}Balance:${NC} $(echo "scale=4; $BALANCE / 1000000000" | bc) SOL"

MIN_BALANCE=1000000000  # 1 SOL minimum
if [ "$BALANCE" -lt "$MIN_BALANCE" ]; then
    echo -e "${RED}✗ Insufficient balance${NC}"
    echo -e "${YELLOW}Minimum required: 1 SOL${NC}"

    if [ "$CLUSTER" = "devnet" ] || [ "$CLUSTER" = "localnet" ]; then
        echo -e "${YELLOW}Requesting airdrop...${NC}"
        solana airdrop 2
        sleep 5
        echo -e "${GREEN}✓ Airdrop received${NC}"
    else
        exit 1
    fi
fi

echo -e "${GREEN}✓ Wallet OK${NC}"
echo ""

# Step 4: Build program
echo -e "${YELLOW}[4/7] Building program...${NC}"
anchor build --verifiable
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Step 5: Get program ID
echo -e "${YELLOW}[5/7] Getting program ID...${NC}"
PROGRAM_ID=$(solana address -k target/deploy/${PROGRAM_NAME}-keypair.json)
echo -e "${BLUE}Program ID:${NC} $PROGRAM_ID"
echo ""

# Step 6: Deploy program
echo -e "${YELLOW}[6/7] Deploying program to $CLUSTER...${NC}"
anchor deploy --provider.cluster $CLUSTER

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Program deployed successfully${NC}"
else
    echo -e "${RED}✗ Deployment failed${NC}"
    exit 1
fi
echo ""

# Step 7: Verify deployment
echo -e "${YELLOW}[7/7] Verifying deployment...${NC}"
DEPLOYED_PROGRAM=$(solana program show $PROGRAM_ID --output json 2>/dev/null | jq -r '.programId')

if [ "$DEPLOYED_PROGRAM" = "$PROGRAM_ID" ]; then
    echo -e "${GREEN}✓ Deployment verified${NC}"
else
    echo -e "${RED}✗ Verification failed${NC}"
    exit 1
fi
echo ""

# Generate deployment report
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
REPORT_FILE="deployment-report-$(date +%Y%m%d-%H%M%S).txt"

cat > "$REPORT_FILE" <<EOF
═══════════════════════════════════════════════════
  Solana Donation Contract - Deployment Report
═══════════════════════════════════════════════════

Timestamp: $TIMESTAMP
Cluster: $CLUSTER
Program ID: $PROGRAM_ID
Deployer: $WALLET

Program Details:
$(solana program show $PROGRAM_ID)

Transaction Cost:
$(solana transaction-count)

Next Steps:
1. Save the program ID: $PROGRAM_ID
2. Update Anchor.toml with the program ID
3. Initialize the vault: anchor run initialize
4. Verify on explorer: https://explorer.solana.com/address/$PROGRAM_ID?cluster=$CLUSTER

═══════════════════════════════════════════════════
EOF

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Program ID:${NC} $PROGRAM_ID"
echo -e "${BLUE}Cluster:${NC} $CLUSTER"
echo -e "${BLUE}Explorer:${NC} https://explorer.solana.com/address/$PROGRAM_ID?cluster=$CLUSTER"
echo ""
echo -e "${YELLOW}Report saved to: $REPORT_FILE${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Update Anchor.toml with program ID"
echo "  2. Initialize the vault"
echo "  3. Test the deployment"
echo ""
