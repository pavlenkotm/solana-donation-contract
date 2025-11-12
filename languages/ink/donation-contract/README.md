# Ink! Donation Contract (Polkadot/Substrate)

A production-ready donation smart contract written in Ink! for Polkadot parachains and Substrate-based blockchains.

## Features

- **Payable Donations**: Native DOT/token transfer support
- **Donor Tier System**: Automatic tier assignment based on contributions
- **Access Control**: Admin-only privileged operations
- **Pausable Pattern**: Emergency stop mechanism
- **Event Emission**: Comprehensive on-chain event logging
- **Balance Tracking**: Per-donor contribution tracking
- **Withdrawal Management**: Partial and emergency withdrawal support

## Tech Stack

- **Ink!** 5.0 - Rust eDSL for Substrate smart contracts
- **Rust** 1.75+ - Systems programming language
- **Substrate** - Blockchain framework for Polkadot ecosystem
- **cargo-contract** - Build and deployment tool

## Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install cargo-contract
cargo install cargo-contract --force

# Verify installation
cargo contract --version  # Should be 4.0+
```

## Installation

```bash
cd languages/ink/donation-contract

# Build the contract
cargo contract build

# Run tests
cargo test

# Run end-to-end tests
cargo test --features e2e-tests
```

## Contract Structure

### Storage

```rust
pub struct DonationContract {
    admin: AccountId,                           // Contract administrator
    total_donations: Balance,                   // Total donations received
    donor_amounts: Mapping<AccountId, Balance>, // Donor contributions
    donor_count: u32,                           // Number of unique donors
    min_donation: Balance,                      // Minimum donation (e.g., 0.01 DOT)
    max_donation: Balance,                      // Maximum donation (e.g., 100 DOT)
    paused: bool,                               // Contract pause state
    initialized: bool,                          // Initialization flag
}
```

### Donor Tiers

| Tier | Minimum Donation | Badge |
|------|-----------------|-------|
| Bronze | 0.01 DOT | 🥉 |
| Silver | 0.1 DOT | 🥈 |
| Gold | 1 DOT | 🥇 |
| Platinum | 10 DOT | 💎 |

*Note: 1 DOT = 10^10 Planck (smallest unit)*

## Usage

### Deploy Contract

```bash
# Build optimized contract
cargo contract build --release

# Deploy to local node
cargo contract instantiate \
  --constructor new \
  --suri //Alice \
  --skip-confirm

# Or deploy to testnet
cargo contract instantiate \
  --constructor new \
  --url wss://rococo-contracts-rpc.polkadot.io \
  --suri "your mnemonic phrase" \
  --skip-confirm
```

### Initialize Contract

```bash
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message initialize \
  --args $ADMIN_ADDRESS 10000000000 1000000000000 \
  --suri //Alice \
  --skip-confirm
```

### Make a Donation

```bash
# Donate 1 DOT (10^10 Planck)
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message donate \
  --value 10000000000 \
  --suri //Bob \
  --skip-confirm
```

### Admin Operations

```bash
# Withdraw 0.5 DOT to recipient
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message withdraw \
  --args 5000000000 $RECIPIENT_ADDRESS \
  --suri //Alice \
  --skip-confirm

# Pause contract
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message pause \
  --suri //Alice \
  --skip-confirm

# Unpause contract
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message unpause \
  --suri //Alice \
  --skip-confirm

# Emergency withdrawal (all funds)
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message emergency_withdraw \
  --args $RECIPIENT_ADDRESS \
  --suri //Alice \
  --skip-confirm
```

### Query Contract State

```bash
# Get total donations
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message get_total_donations \
  --dry-run

# Get donor's contribution
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message get_donor_amount \
  --args $DONOR_ADDRESS \
  --dry-run

# Get donor's tier
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message get_donor_tier \
  --args $DONOR_ADDRESS \
  --dry-run

# Check if paused
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message is_paused \
  --dry-run

# Get contract balance
cargo contract call \
  --contract $CONTRACT_ADDRESS \
  --message get_balance \
  --dry-run
```

## Integration with JavaScript/TypeScript

```typescript
import { ApiPromise, WsProvider } from '@polkadot/api';
import { ContractPromise } from '@polkadot/api-contract';

// Connect to node
const provider = new WsProvider('ws://localhost:9944');
const api = await ApiPromise.create({ provider });

// Load contract
const contract = new ContractPromise(
  api,
  contractAbi,
  contractAddress
);

// Make a donation
const value = api.registry.createType('Balance', '10000000000'); // 1 DOT
await contract.tx
  .donate({ value })
  .signAndSend(donor, (result) => {
    if (result.status.isInBlock) {
      console.log('Donation successful!');
    }
  });

// Query donor amount
const { output } = await contract.query.getDonorAmount(
  donor.address,
  { value: 0, gasLimit: -1 },
  donorAddress
);
console.log('Donor amount:', output.toHuman());
```

## Testing

### Unit Tests

```bash
# Run unit tests
cargo test

# Run tests with output
cargo test -- --nocapture
```

### Integration Tests

```bash
# Start local Substrate node
substrate-contracts-node --dev

# Run E2E tests
cargo test --features e2e-tests
```

### Example Test

```rust
#[ink::test]
fn test_donation_workflow() {
    let mut contract = DonationContract::new();
    let admin = AccountId::from([0x1; 32]);

    // Initialize
    assert!(contract.initialize(
        admin,
        10_000_000_000,      // 1 DOT min
        100_000_000_000_000  // 10,000 DOT max
    ).is_ok());

    // Verify initialization
    assert_eq!(contract.get_admin(), admin);
    assert_eq!(contract.get_total_donations(), 0);
}
```

## Events

### DonationReceived

Emitted when a donation is made.

```rust
pub struct DonationReceived {
    donor: AccountId,
    amount: Balance,
    total: Balance,
    tier: u8,
    timestamp: Timestamp,
}
```

### Withdrawal

Emitted when admin withdraws funds.

```rust
pub struct Withdrawal {
    admin: AccountId,
    amount: Balance,
    recipient: AccountId,
    timestamp: Timestamp,
}
```

## Error Handling

```rust
pub enum Error {
    AlreadyInitialized,    // Contract already initialized
    NotInitialized,        // Contract not initialized
    NotAdmin,              // Caller is not admin
    ContractPaused,        // Contract is paused
    ContractNotPaused,     // Contract is not paused
    DonationTooSmall,      // Donation below minimum
    DonationTooLarge,      // Donation above maximum
    InvalidLimits,         // Invalid min/max limits
    InsufficientBalance,   // Not enough balance
    TransferFailed,        // Transfer operation failed
}
```

## Security Features

1. **Access Control**: Only admin can perform privileged operations
2. **Pausable Pattern**: Emergency pause mechanism
3. **Overflow Protection**: Saturating arithmetic operations
4. **Donation Limits**: Min/max constraints prevent abuse
5. **Initialization Guard**: Single initialization enforcement
6. **Comprehensive Events**: Full audit trail
7. **Rust Safety**: Memory safety and type safety guarantees

## Gas Optimization

- Efficient `Mapping` storage structure
- Minimal storage updates per transaction
- Event emission for off-chain indexing
- Saturating arithmetic to prevent panics

## Ink! Advantages

| Feature | Benefit |
|---------|---------|
| Rust-Based | Memory safety and zero-cost abstractions |
| Type Safety | Compile-time guarantees and error prevention |
| Polkadot Ecosystem | Access to cross-chain messaging (XCM) |
| Small Wasm Binaries | Efficient on-chain storage |
| Native Testing | Built-in unit and E2E testing |
| Upgradeable | Proxy pattern support for upgrades |

## Advanced Features

### Custom Events

```rust
#[ink(event)]
pub struct TierUpgrade {
    #[ink(topic)]
    donor: AccountId,
    old_tier: u8,
    new_tier: u8,
}
```

### View Functions with Parameters

```rust
#[ink(message)]
pub fn get_donors_by_tier(&self, tier: u8) -> Vec<AccountId> {
    // Implementation
}
```

### Multi-Token Support

```rust
use ink::env::call::{ExecutionInput, Selector};

#[ink(message)]
pub fn donate_erc20(&mut self, token: AccountId, amount: Balance) -> Result<()> {
    // Transfer ERC-20 tokens
    let result = build_call::<DefaultEnvironment>()
        .call(token)
        .exec_input(
            ExecutionInput::new(Selector::new([0x09, 0x84, 0x29, 0x0c])) // transfer
                .push_arg(self.env().account_id())
                .push_arg(amount)
        )
        .returns::<()>()
        .invoke();

    // Handle result
    Ok(())
}
```

## Deployment Networks

### Polkadot Ecosystem

- **Astar** - Smart contract parachain with EVM + Wasm support
- **Shiden** - Kusama's smart contract hub
- **Contracts Parachain** - Dedicated contracts chain
- **Rococo** - Polkadot testnet

### Local Development

```bash
# Start local node
substrate-contracts-node --dev --tmp

# Or use Substrate node
polkadot --dev --tmp
```

## Troubleshooting

### Build Errors

```bash
# Clean and rebuild
cargo clean
cargo contract build

# Update dependencies
cargo update
```

### Contract Size Too Large

```bash
# Build with optimizations
cargo contract build --release

# Use wasm-opt
wasm-opt -Oz -o optimized.wasm target.wasm
```

### Gas Limit Issues

```bash
# Increase gas limit in call
cargo contract call \
  --gas 200000000000 \
  ...
```

## Resources

- [Ink! Documentation](https://use.ink/) - Official Ink! guide
- [Substrate Docs](https://docs.substrate.io/) - Substrate framework
- [Polkadot Wiki](https://wiki.polkadot.network/) - Polkadot ecosystem
- [cargo-contract](https://github.com/paritytech/cargo-contract) - Build tool
- [Contracts UI](https://contracts-ui.substrate.io/) - Web interface

## Why Ink! for Smart Contracts?

1. **Rust Ecosystem**: Access to mature libraries and tools
2. **Safety First**: Memory safety without garbage collection
3. **Performance**: Near-native execution speed
4. **Interoperability**: Cross-chain messaging with XCM
5. **Developer Experience**: Excellent tooling and IDE support
6. **Future-Proof**: Built on Substrate's modular architecture

## Common Patterns

### Upgrade Pattern

```rust
#[ink(message)]
pub fn set_code(&mut self, code_hash: [u8; 32]) -> Result<()> {
    self.only_admin()?;
    ink::env::set_code_hash(&code_hash)?;
    Ok(())
}
```

### Reentrancy Guard

```rust
#[ink(storage)]
pub struct DonationContract {
    // ... other fields
    locked: bool,
}

fn non_reentrant(&mut self) -> Result<()> {
    if self.locked {
        return Err(Error::ReentrancyDetected);
    }
    self.locked = true;
    Ok(())
}
```

## License

MIT License

## Contributing

Contributions are welcome! Please ensure:
- Code passes `cargo clippy`
- Tests are included
- Documentation is updated
- Follows Ink! best practices
