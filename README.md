# 🪙 Solana Donation Contract

A **production-ready Solana smart contract** built with Rust and the Anchor framework. This contract enables users to donate SOL securely, with full administrative control over withdrawals.

## ✨ Features

- **Secure Donations**: Accept SOL donations with configurable min/max limits
- **PDA-Based Vault**: Uses Program Derived Addresses for enhanced security
- **Admin Management**: Withdraw funds and transfer admin rights
- **State Tracking**: Monitor total donations and donation count
- **Event Emission**: DonationEvent and WithdrawEvent for off-chain monitoring
- **Comprehensive Error Handling**: Custom error types for better debugging
- **Overflow Protection**: Safe math operations throughout
- **Rent Exemption**: Maintains minimum balance for rent exemption

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

Make a donation to the vault.

```rust
pub fn donate(ctx: Context<Donate>, amount: u64) -> Result<()>
```

**Parameters:**
- `amount` - Amount in lamports (min: 0.001 SOL, max: 100 SOL)

**Accounts:**
- `donor` - The donor making the donation (signer, mutable)
- `vault_state` - The vault state PDA (mutable)
- `vault` - The vault PDA (mutable)
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

### 4. Update Admin

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

### State Structure

```rust
pub struct VaultState {
    pub admin: Pubkey,           // Admin public key
    pub total_donated: u64,      // Total lamports donated
    pub donation_count: u64,     // Number of donations
    pub bump: u8,                // PDA bump seed
}
```

### Events

```rust
pub struct DonationEvent {
    pub donor: Pubkey,
    pub amount: u64,
    pub total_donated: u64,
}

pub struct WithdrawEvent {
    pub admin: Pubkey,
    pub amount: u64,
}
```

### Custom Errors

- `DonationTooSmall` - Donation below 0.001 SOL
- `DonationTooLarge` - Donation exceeds 100 SOL
- `Unauthorized` - Non-admin attempted admin action
- `InsufficientFunds` - Vault has insufficient balance
- `Overflow` - Arithmetic overflow detected

## 🔐 Security Features

1. **PDA Validation**: All PDAs use seed-based derivation
2. **Admin Authorization**: Admin-only functions verified on-chain
3. **Donation Limits**: Configurable min/max donation amounts
4. **Overflow Protection**: Checked arithmetic operations
5. **Rent Exemption**: Maintains minimum balance to prevent account deletion
6. **CPI Safety**: Uses Anchor's type-safe CPI for transfers

## 🧪 Testing

```bash
# Run all tests
anchor test

# Run tests with logs
anchor test -- --nocapture

# Run specific test
anchor test -t initialize_test
```

## 📝 Usage Example

```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Donation } from "../target/types/donation";

// Initialize
const [vaultStatePDA] = anchor.web3.PublicKey.findProgramAddressSync(
  [Buffer.from("vault_state")],
  program.programId
);

const [vaultPDA] = anchor.web3.PublicKey.findProgramAddressSync(
  [Buffer.from("vault")],
  program.programId
);

await program.methods
  .initialize()
  .accounts({
    admin: admin.publicKey,
    vaultState: vaultStatePDA,
    vault: vaultPDA,
    systemProgram: anchor.web3.SystemProgram.programId,
  })
  .rpc();

// Donate
await program.methods
  .donate(new anchor.BN(1_000_000)) // 0.001 SOL
  .accounts({
    donor: donor.publicKey,
    vaultState: vaultStatePDA,
    vault: vaultPDA,
    systemProgram: anchor.web3.SystemProgram.programId,
  })
  .rpc();

// Withdraw (admin only)
await program.methods
  .withdraw()
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

- `MIN_DONATION`: 1,000,000 lamports (0.001 SOL)
- `MAX_DONATION`: 100,000,000,000 lamports (100 SOL)

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
