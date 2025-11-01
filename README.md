# 🪙 Solana Donation Contract

A **production-ready Solana smart contract** built with Rust and the Anchor framework. This advanced donation platform features donor tracking, tier-based rewards, pause controls, and comprehensive admin tools.

## ✨ Features

### Core Features
- **Secure Donations**: Accept SOL donations with configurable min/max limits (0.001 - 100 SOL)
- **PDA-Based Vault**: Uses Program Derived Addresses for enhanced security
- **Donor Tracking**: Individual donor statistics and contribution history
- **Tier System**: 4-tier classification (Bronze, Silver, Gold, Platinum)
- **Pause/Unpause**: Emergency stop mechanism for contract security
- **Flexible Withdrawals**: Both full and partial withdrawal support
- **Admin Management**: Transfer ownership and administrative controls

### Advanced Features
- **State Tracking**: Monitor total donations, counts, and individual donor stats
- **Event Emission**: Rich events for donations, withdrawals, and pause state changes
- **Timestamp Tracking**: Records last donation time for each donor
- **Comprehensive Error Handling**: Custom error types for better debugging
- **Overflow Protection**: Safe math operations throughout
- **Rent Exemption**: Maintains minimum balance for rent exemption

### Developer Tools
- **TypeScript Client SDK**: Full-featured SDK with event listeners
- **Comprehensive Tests**: 21+ test cases covering all functionality
- **Code Examples**: Ready-to-use integration examples

## 🧰 Tech Stack

- **Rust** (Edition 2021)
- **Anchor Framework** v0.30.1
- **Solana** runtime (BPF)

## 📋 Prerequisites

- Rust 1.75.0 or higher
- Solana CLI 1.18.0 or higher
- Anchor CLI 0.30.1 or higher
- Node.js 18+ (for testing)

## 🚀 Installation

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

# Install Anchor
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest

# Clone repository
git clone https://github.com/yourusername/solana-donation-contract.git
cd solana-donation-contract

# Install dependencies
npm install
```

## 🔨 Build

```bash
# Build the program
anchor build

# Run tests
anchor test

# Deploy to devnet
anchor deploy --provider.cluster devnet
```

## 📖 Program Instructions

### 1. Initialize

Initialize a new donation vault (must be called first).

```rust
pub fn initialize(ctx: Context<Initialize>) -> Result<()>
```

**Accounts:**
- `admin` - The admin who will manage the vault (signer, mutable)
- `vault_state` - The vault state PDA (init, seeds: ["vault_state"])
- `vault` - The vault PDA that holds donations (seeds: ["vault"])
- `system_program` - Solana System Program

### 2. Donate

Make a donation to the vault. Automatically tracks donor statistics and tier.

```rust
pub fn donate(ctx: Context<Donate>, amount: u64) -> Result<()>
```

**Parameters:**
- `amount` - Amount in lamports (min: 0.001 SOL, max: 100 SOL)

**Accounts:**
- `donor` - The donor making the donation (signer, mutable)
- `vault_state` - The vault state PDA (mutable)
- `vault` - The vault PDA (mutable)
- `donor_info` - The donor info PDA (init_if_needed, seeds: ["donor_info", donor])
- `system_program` - Solana System Program

### 3. Withdraw

Withdraw all funds from the vault (admin only).

```rust
pub fn withdraw(ctx: Context<Withdraw>) -> Result<()>
```

**Accounts:**
- `admin` - The admin withdrawing funds (signer, mutable)
- `vault_state` - The vault state PDA
- `vault` - The vault PDA (mutable)

### 4. Withdraw Partial (NEW)

Withdraw a specific amount from the vault (admin only).

```rust
pub fn withdraw_partial(ctx: Context<Withdraw>, amount: u64) -> Result<()>
```

**Parameters:**
- `amount` - Amount to withdraw in lamports (must be > 0)

**Accounts:**
- `admin` - The admin withdrawing funds (signer, mutable)
- `vault_state` - The vault state PDA
- `vault` - The vault PDA (mutable)

### 5. Pause (NEW)

Pause the donation contract to stop accepting donations (admin only).

```rust
pub fn pause(ctx: Context<UpdateAdmin>) -> Result<()>
```

**Accounts:**
- `admin` - The admin pausing the contract (signer)
- `vault_state` - The vault state PDA (mutable)

### 6. Unpause (NEW)

Unpause the donation contract to resume accepting donations (admin only).

```rust
pub fn unpause(ctx: Context<UpdateAdmin>) -> Result<()>
```

**Accounts:**
- `admin` - The admin unpausing the contract (signer)
- `vault_state` - The vault state PDA (mutable)

### 7. Update Admin

Transfer admin rights to a new address.

```rust
pub fn update_admin(ctx: Context<UpdateAdmin>, new_admin: Pubkey) -> Result<()>
```

**Parameters:**
- `new_admin` - Public key of the new admin

**Accounts:**
- `admin` - The current admin (signer)
- `vault_state` - The vault state PDA (mutable)

## 🏗️ Program Architecture

### State Structures

```rust
pub struct VaultState {
    pub admin: Pubkey,           // Admin public key
    pub total_donated: u64,      // Total lamports donated (all donors)
    pub donation_count: u64,     // Number of donations (all donors)
    pub is_paused: bool,         // Whether contract is paused (NEW)
    pub bump: u8,                // PDA bump seed
}

pub struct DonorInfo {           // NEW
    pub donor: Pubkey,           // Donor's public key
    pub total_donated: u64,      // Total donated by this donor
    pub donation_count: u64,     // Number of donations by this donor
    pub last_donation_timestamp: i64,  // Unix timestamp of last donation
    pub tier: DonorTier,         // Current donor tier
}

pub enum DonorTier {             // NEW
    Bronze,                      // ≥ 0.001 SOL
    Silver,                      // ≥ 0.1 SOL
    Gold,                        // ≥ 1 SOL
    Platinum,                    // ≥ 10 SOL
}
```

### Events

```rust
pub struct DonationEvent {
    pub donor: Pubkey,
    pub amount: u64,
    pub total_donated: u64,
    pub donor_tier: DonorTier,   // NEW
}

pub struct WithdrawEvent {
    pub admin: Pubkey,
    pub amount: u64,
}

pub struct PauseEvent {          // NEW
    pub admin: Pubkey,
    pub paused: bool,
}
```

### Custom Errors

- `DonationTooSmall` - Donation below 0.001 SOL
- `DonationTooLarge` - Donation exceeds 100 SOL
- `Unauthorized` - Non-admin attempted admin action
- `InsufficientFunds` - Vault has insufficient balance
- `Overflow` - Arithmetic overflow detected
- `ContractPaused` - Donations blocked when paused (NEW)
- `InvalidAmount` - Invalid withdrawal amount (NEW)

## 🏆 Donor Tier System

The contract automatically tracks and assigns tiers to donors based on their cumulative contributions:

| Tier | Threshold | Benefits |
|------|-----------|----------|
| 🥉 Bronze | ≥ 0.001 SOL | Entry level recognition |
| 🥈 Silver | ≥ 0.1 SOL | Milestone achievement |
| 🥇 Gold | ≥ 1 SOL | Premium contributor |
| 💎 Platinum | ≥ 10 SOL | Elite supporter |

Tiers are calculated automatically on each donation and stored in the donor's on-chain profile. This enables:
- Recognition systems for top donors
- Tier-based rewards and benefits
- Gamification of donation campaigns
- Historical tracking of donor progression

## 🔐 Security Features

1. **PDA Validation**: All PDAs use seed-based derivation
2. **Admin Authorization**: Admin-only functions verified on-chain
3. **Donation Limits**: Configurable min/max donation amounts (0.001-100 SOL)
4. **Overflow Protection**: Checked arithmetic operations throughout
5. **Rent Exemption**: Maintains minimum balance to prevent account deletion
6. **CPI Safety**: Uses Anchor's type-safe CPI for transfers
7. **Pause Mechanism**: Emergency stop for security incidents (NEW)
8. **State Validation**: All state transitions validated before execution

## 🧪 Testing

The project includes a comprehensive test suite with 21+ test cases covering all functionality:

```bash
# Run all tests
anchor test

# Run tests with logs
anchor test -- --nocapture
```

### Test Coverage
- ✅ Initialization and setup
- ✅ All donation tiers (Bronze, Silver, Gold, Platinum)
- ✅ Tier progression tracking
- ✅ Min/max donation validation
- ✅ Pause/unpause functionality
- ✅ Full and partial withdrawals
- ✅ Admin authorization checks
- ✅ Donor statistics tracking
- ✅ Error conditions and edge cases

See `tests/donation.test.ts` for the complete test suite.

## 🛠️ Client SDK

The project includes a full-featured TypeScript client SDK (`examples/client-example.ts`) for easy integration:

```typescript
import { DonationClient } from "./examples/client-example";
import { Connection, Keypair } from "@solana/web3.js";
import * as anchor from "@coral-xyz/anchor";

// Setup
const connection = new Connection("https://api.devnet.solana.com");
const wallet = anchor.Wallet.local();
const client = new DonationClient(connection, wallet, programId);

// Make a donation
await client.donate(donorKeypair, 0.1 * LAMPORTS_PER_SOL);

// Get vault state
const vaultState = await client.getVaultState();
console.log("Total donated:", vaultState.totalDonatedSOL, "SOL");

// Get donor info
const donorInfo = await client.getDonorInfo(donor.publicKey);
console.log("Tier:", donorInfo.tier); // bronze, silver, gold, or platinum

// Admin: Pause contract
await client.pause(adminKeypair);

// Admin: Partial withdrawal
await client.withdrawPartial(adminKeypair, 0.5 * LAMPORTS_PER_SOL);

// Listen to events
client.onDonation((event) => {
  console.log(`New donation: ${event.amountSOL} SOL (${event.donorTier})`);
});
```

### SDK Features
- ✅ Simple, intuitive API
- ✅ Automatic PDA derivation
- ✅ Type-safe operations
- ✅ Event listeners for real-time updates
- ✅ Lamports ↔ SOL conversion helpers
- ✅ Comprehensive error handling

## 📝 Usage Example (Raw Anchor)

```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Donation } from "../target/types/donation";

// Derive PDAs
const [vaultStatePDA] = anchor.web3.PublicKey.findProgramAddressSync(
  [Buffer.from("vault_state")],
  program.programId
);

const [vaultPDA] = anchor.web3.PublicKey.findProgramAddressSync(
  [Buffer.from("vault")],
  program.programId
);

const [donorInfoPDA] = anchor.web3.PublicKey.findProgramAddressSync(
  [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
  program.programId
);

// Initialize vault
await program.methods
  .initialize()
  .accounts({
    admin: admin.publicKey,
    vaultState: vaultStatePDA,
    vault: vaultPDA,
    systemProgram: anchor.web3.SystemProgram.programId,
  })
  .rpc();

// Make a donation
await program.methods
  .donate(new anchor.BN(1_000_000)) // 0.001 SOL
  .accounts({
    donor: donor.publicKey,
    vaultState: vaultStatePDA,
    vault: vaultPDA,
    donorInfo: donorInfoPDA,
    systemProgram: anchor.web3.SystemProgram.programId,
  })
  .rpc();

// Pause contract (admin only)
await program.methods
  .pause()
  .accounts({
    admin: admin.publicKey,
    vaultState: vaultStatePDA,
  })
  .rpc();

// Partial withdrawal (admin only)
await program.methods
  .withdrawPartial(new anchor.BN(500_000_000))
  .accounts({
    admin: admin.publicKey,
    vaultState: vaultStatePDA,
    vault: vaultPDA,
  })
  .rpc();
```

## 🌐 Deployment

### Devnet

```bash
# Configure Solana CLI for devnet
solana config set --url devnet

# Request airdrop for testing
solana airdrop 2

# Deploy program
anchor deploy --provider.cluster devnet

# Note the program ID and update it in lib.rs
```

### Mainnet

```bash
# Configure for mainnet
solana config set --url mainnet-beta

# Deploy (ensure you have sufficient SOL)
anchor deploy --provider.cluster mainnet-beta
```

## 📊 Constants

### Donation Limits
- `MIN_DONATION`: 1,000,000 lamports (0.001 SOL)
- `MAX_DONATION`: 100,000,000,000 lamports (100 SOL)

### Tier Thresholds
- `TIER_BRONZE`: 1,000,000 lamports (0.001 SOL)
- `TIER_SILVER`: 100,000,000 lamports (0.1 SOL)
- `TIER_GOLD`: 1,000,000,000 lamports (1 SOL)
- `TIER_PLATINUM`: 10,000,000,000 lamports (10 SOL)

## 🆕 What's New in This Version

This contract has been significantly enhanced with production-ready features:

### New Features
- 🎯 **Donor Tracking**: Individual donor profiles with statistics
- 🏆 **Tier System**: 4-tier classification (Bronze, Silver, Gold, Platinum)
- ⏸️ **Pause/Unpause**: Emergency stop mechanism
- 💰 **Partial Withdrawals**: Flexible fund management
- 📊 **Enhanced Events**: Richer event data with tier information
- ⏰ **Timestamp Tracking**: Records last donation time

### Developer Tools
- 🧪 **Comprehensive Tests**: 21+ test cases with full coverage
- 🛠️ **Client SDK**: Full-featured TypeScript SDK
- 📖 **Code Examples**: Ready-to-use integration examples
- 📚 **Documentation**: Extensive inline and external docs

### Technical Improvements
- Better code organization and documentation
- Enhanced security with pause mechanism
- Improved error handling
- Type-safe enums and helper functions
- Professional code structure

See `IMPROVEMENTS.md` for detailed documentation of all changes.

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Resources

- [Anchor Documentation](https://www.anchor-lang.com/)
- [Solana Documentation](https://docs.solana.com/)
- [Solana Cookbook](https://solanacookbook.com/)

## ⚠️ Disclaimer

This code is provided as-is for educational purposes. Audit thoroughly before using in production.

## 👥 Authors

Built with ❤️ using Anchor Framework

---

**Need help?** Open an issue or check the [Anchor Discord](https://discord.gg/anchor)
