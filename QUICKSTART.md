# 🚀 Quick Start Guide

Get your Solana Donation Contract up and running in minutes!

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v18 or higher) - [Download](https://nodejs.org/)
- **Rust** (latest stable) - [Install](https://rustup.rs/)
- **Solana CLI** (v1.18+) - [Install](https://docs.solana.com/cli/install-solana-cli-tools)
- **Anchor** (v0.30.1) - [Install](https://www.anchor-lang.com/docs/installation)

## Installation

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd solana-donation-contract
```

### 2. Run Setup Script

The setup script will install dependencies and prepare your environment:

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

Or manually:

```bash
# Install Node.js dependencies
npm install

# Build the Solana program
anchor build
```

### 3. Configure Environment

Copy the example environment file and customize it:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
SOLANA_NETWORK=devnet
PROGRAM_ID=DoNaT1on111111111111111111111111111111111111
ADMIN_KEYPAIR_PATH=./keypairs/admin.json
```

### 4. Generate Keypairs

Generate keypairs for testing:

```bash
# Create keypairs directory
mkdir -p keypairs

# Generate admin keypair
solana-keygen new --outfile keypairs/admin.json

# Generate donor keypair for testing
solana-keygen new --outfile keypairs/donor.json
```

### 5. Get Devnet SOL

Airdrop SOL to your accounts for testing:

```bash
# Get admin address
solana address -k keypairs/admin.json

# Airdrop SOL to admin
solana airdrop 2 $(solana address -k keypairs/admin.json) --url devnet

# Airdrop SOL to donor
solana airdrop 2 $(solana address -k keypairs/donor.json) --url devnet
```

## Building & Testing

### Build the Program

```bash
# Using Anchor
anchor build

# Or using the build script
./scripts/build-all.sh
```

### Run Tests

```bash
# Run all tests (requires local validator)
anchor test

# Or run without starting a new validator
anchor test --skip-local-validator

# Using npm
npm test
```

### Check Compilation

```bash
# Check Rust code
cargo check --manifest-path programs/donation/Cargo.toml

# Or use the test script
./scripts/test-all.sh
```

## Deployment

### Deploy to Devnet

```bash
# Using Anchor
anchor deploy --provider.cluster devnet

# Or using npm script
npm run deploy:devnet
```

After deployment, update the `PROGRAM_ID` in:
- `.env`
- `Anchor.toml`
- `programs/donation/src/lib.rs` (in `declare_id!`)
- `utils/constants.ts`

### Deploy to Mainnet

⚠️ **Warning**: Only deploy to mainnet after thorough testing and security audit!

```bash
# Set Solana to mainnet
solana config set --url mainnet-beta

# Deploy
npm run deploy:mainnet
```

## Usage Examples

### Initialize the Vault

```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Donation } from "../target/types/donation";

// Load program
const program = anchor.workspace.Donation as Program<Donation>;

// Initialize vault
await program.methods
  .initialize()
  .accounts({
    admin: adminKeypair.publicKey,
    vaultState,
    vault,
    systemProgram: anchor.web3.SystemProgram.programId,
  })
  .signers([adminKeypair])
  .rpc();
```

### Make a Donation

```typescript
// Donate 0.1 SOL
const amount = new anchor.BN(100_000_000); // 0.1 SOL in lamports

await program.methods
  .donate(amount)
  .accounts({
    donor: donorKeypair.publicKey,
    vaultState,
    vault,
    donorInfo,
    systemProgram: anchor.web3.SystemProgram.programId,
  })
  .signers([donorKeypair])
  .rpc();
```

### Withdraw Funds (Admin Only)

```typescript
// Partial withdrawal
const withdrawAmount = new anchor.BN(50_000_000); // 0.05 SOL

await program.methods
  .withdrawPartial(withdrawAmount)
  .accounts({
    admin: adminKeypair.publicKey,
    vaultState,
    vault,
    systemProgram: anchor.web3.SystemProgram.programId,
  })
  .signers([adminKeypair])
  .rpc();
```

## Project Structure

```
solana-donation-contract/
├── programs/donation/          # Rust smart contract
│   └── src/lib.rs             # Main program code
├── tests/                     # Integration tests
│   ├── donation.test.ts       # Main test suite
│   └── benchmark.test.ts      # Performance tests
├── examples/                  # Usage examples
│   ├── client-example.ts      # Basic client SDK
│   └── advanced-usage.ts      # Advanced patterns
├── utils/                     # Utility functions
├── types/                     # TypeScript types
├── scripts/                   # Helper scripts
│   ├── setup.sh              # Environment setup
│   ├── build-all.sh          # Build all components
│   └── test-all.sh           # Run all tests
├── languages/                 # Multi-language examples
│   ├── solidity/             # Ethereum/EVM
│   ├── vyper/                # Python-like smart contracts
│   ├── move/                 # Aptos blockchain
│   ├── typescript/           # DApp frontend
│   ├── python/               # Web3 utilities
│   ├── go/                   # Signature verification
│   ├── java/                 # Web3j integration
│   ├── swift/                # iOS wallet SDK
│   ├── cpp/                  # Cryptographic algorithms
│   └── html-css/             # Landing page
└── keypairs/                  # Local keypairs (gitignored)
```

## Available Commands

### NPM Scripts

```bash
npm run build          # Build the Anchor program
npm test              # Run tests
npm run lint          # Check code formatting
npm run lint:fix      # Fix formatting issues
npm run deploy:devnet # Deploy to devnet
```

### Anchor Commands

```bash
anchor build          # Build the program
anchor test           # Run tests
anchor deploy         # Deploy to configured cluster
anchor upgrade        # Upgrade existing program
```

## Troubleshooting

### Common Issues

**1. "anchor: command not found"**
```bash
# Install Anchor
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest
```

**2. "Insufficient funds"**
```bash
# Get more devnet SOL
solana airdrop 2 <your-address> --url devnet
```

**3. "Program ID mismatch"**
- Make sure all Program IDs match across:
  - `programs/donation/src/lib.rs`
  - `Anchor.toml`
  - `.env`
  - `utils/constants.ts`

**4. "Failed to build"**
```bash
# Clean and rebuild
cargo clean
anchor clean
anchor build
```

**5. "Tests failing"**
```bash
# Ensure local validator is running
solana-test-validator

# In another terminal, run tests
anchor test --skip-local-validator
```

## Next Steps

1. ✅ Review the [API Documentation](API.md)
2. ✅ Check [Security Guidelines](SECURITY.md)
3. ✅ Read [Contributing Guide](CONTRIBUTING.md)
4. ✅ Explore [Multi-Language Examples](MULTI_LANG_README.md)
5. ✅ Review [Changelog](CHANGELOG.md)

## Support

- **Documentation**: See [README.md](README.md) for comprehensive docs
- **Examples**: Check the `examples/` directory
- **Issues**: Report bugs via GitHub Issues
- **Community**: Join our Discord/Telegram (if available)

## Resources

- [Solana Documentation](https://docs.solana.com/)
- [Anchor Framework](https://www.anchor-lang.com/)
- [Solana Cookbook](https://solanacookbook.com/)
- [Solana Stack Exchange](https://solana.stackexchange.com/)

---

**Happy Building! 🎉**

For detailed information, see the full [README.md](README.md)
