#!/bin/bash

# Initialize Donation Vault
# Usage: ./scripts/initialize.sh [devnet|mainnet-beta|localnet]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER=${1:-devnet}

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Initialize Donation Vault${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Configure cluster
solana config set --url $CLUSTER
echo -e "${GREEN}✓ Configured for $CLUSTER${NC}"
echo ""

# Get wallet info
ADMIN=$(solana address)
echo -e "${BLUE}Admin Wallet:${NC} $ADMIN"
echo ""

# Build if needed
if [ ! -f "target/deploy/donation.so" ]; then
    echo -e "${YELLOW}Building program...${NC}"
    anchor build
fi

# Get program ID
PROGRAM_ID=$(solana address -k target/deploy/donation-keypair.json)
echo -e "${BLUE}Program ID:${NC} $PROGRAM_ID"
echo ""

# Initialize vault
echo -e "${YELLOW}Initializing vault...${NC}"

# Note: This would need the actual TypeScript/Anchor command
# For now, we'll show the manual process

cat <<EOF
To initialize the vault, run:

  npx ts-node -e "
  import * as anchor from '@coral-xyz/anchor';
  import { Program } from '@coral-xyz/anchor';
  import { Donation } from './target/types/donation';

  (async () => {
    const provider = anchor.AnchorProvider.env();
    anchor.setProvider(provider);

    const program = anchor.workspace.Donation as Program<Donation>;

    const [vaultStatePDA] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from('vault_state')],
      program.programId
    );

    const [vaultPDA] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from('vault')],
      program.programId
    );

    const tx = await program.methods
      .initialize()
      .accounts({
        admin: provider.wallet.publicKey,
        vaultState: vaultStatePDA,
        vault: vaultPDA,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    console.log('✓ Vault initialized! Transaction:', tx);
    console.log('Vault State PDA:', vaultStatePDA.toString());
    console.log('Vault PDA:', vaultPDA.toString());
  })();
  "

Or use the test suite:

  anchor test --skip-build --skip-local-validator

EOF

echo -e "${GREEN}✓ Instructions provided${NC}"
echo ""
