#!/bin/bash

# Deploy Donation Contract to Mainnet-Beta
# Usage: ./scripts/deploy-mainnet.sh

set -e

echo "🚀 Deploying Donation Contract to Mainnet-Beta..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
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

echo -e "${RED}⚠️  WARNING: You are about to deploy to MAINNET-BETA!${NC}"
echo -e "${RED}This will cost real SOL and cannot be undone.${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo -e "${BLUE}📋 Pre-deployment checks...${NC}"

# Set Solana to mainnet-beta
echo "🌐 Setting Solana cluster to mainnet-beta..."
solana config set --url mainnet-beta

# Check wallet balance
BALANCE=$(solana balance)
echo -e "${YELLOW}💰 Wallet balance: $BALANCE${NC}"

# Check if balance is sufficient (need at least 5 SOL for deployment)
MIN_BALANCE=5.0
CURRENT_BALANCE=$(echo $BALANCE | awk '{print $1}')

if (( $(echo "$CURRENT_BALANCE < $MIN_BALANCE" | bc -l) )); then
    echo -e "${RED}❌ Insufficient balance. You need at least 5 SOL for mainnet deployment.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}💸 Estimated deployment cost: ~2-3 SOL${NC}"
read -p "Continue with deployment? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}🔨 Building program (release mode)...${NC}"
anchor build --verifiable

echo ""
echo -e "${BLUE}🔍 Running security checks...${NC}"

# Run clippy for additional checks
cargo clippy -- -D warnings

echo ""
echo -e "${BLUE}🧪 Running tests...${NC}"
anchor test --skip-deploy

echo ""
echo -e "${YELLOW}⚠️  Final confirmation before mainnet deployment${NC}"
read -p "Deploy to mainnet NOW? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}📦 Deploying program to mainnet-beta...${NC}"
PROGRAM_ID=$(anchor deploy --provider.cluster mainnet-beta 2>&1 | grep "Program Id:" | awk '{print $3}')

if [ -z "$PROGRAM_ID" ]; then
    echo "❌ Deployment failed"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Deployment successful!${NC}"
echo -e "${GREEN}📍 Program ID: $PROGRAM_ID${NC}"

# Save program ID and deployment info
mkdir -p .deploy
echo $PROGRAM_ID > .deploy/mainnet-program-id.txt
echo "Deployment Date: $(date)" >> .deploy/mainnet-program-id.txt
echo "Deployer: $(solana address)" >> .deploy/mainnet-program-id.txt

# Create deployment report
cat > .deploy/mainnet-deployment-report.txt << EOF
====================================
MAINNET DEPLOYMENT REPORT
====================================

Program ID: $PROGRAM_ID
Deployment Date: $(date)
Deployer Address: $(solana address)
Cluster: mainnet-beta

Next Steps:
1. Update declare_id! in lib.rs with the new Program ID
2. Verify the program on Solana Explorer
3. Initialize the vault with the admin keypair
4. Test all functionality on mainnet
5. Monitor the program for any issues

IMPORTANT NOTES:
- Keep the deployer keypair secure
- Document the admin keypair location
- Set up monitoring and alerting
- Prepare emergency response procedures

====================================
EOF

echo ""
echo -e "${GREEN}📄 Deployment report saved to .deploy/mainnet-deployment-report.txt${NC}"
echo ""

# Display verification info
echo -e "${BLUE}🔍 Verify your deployment:${NC}"
echo "   Solana Explorer: https://explorer.solana.com/address/$PROGRAM_ID"
echo "   Solscan: https://solscan.io/account/$PROGRAM_ID"
echo ""

echo -e "${YELLOW}⚠️  CRITICAL: Update the program ID in lib.rs:${NC}"
echo "   declare_id!(\"$PROGRAM_ID\");"
echo ""

echo -e "${GREEN}✨ Mainnet deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. ✅ Update program ID in programs/donation/src/lib.rs"
echo "2. ✅ Rebuild and redeploy with updated ID"
echo "3. ✅ Verify program on Solana Explorer"
echo "4. ✅ Initialize vault with admin keypair"
echo "5. ✅ Test all functions on mainnet"
echo "6. ✅ Set up monitoring and alerts"
echo ""
