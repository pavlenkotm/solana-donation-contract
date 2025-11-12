# Rust Donation Contract (NEAR Protocol)

A secure, production-ready donation smart contract written in Rust for NEAR Protocol, featuring sharded scalability and low transaction costs.

## Features

- **Payable Functions**: Native NEAR token transfer support
- **Donor Tier System**: Automatic tier assignment (Bronze, Silver, Gold, Platinum)
- **Access Control**: Admin-only privileged operations
- **Pausable**: Emergency stop mechanism
- **Event Logging**: Comprehensive on-chain event logging
- **Gas Efficient**: Optimized for NEAR's gas model
- **View Functions**: Free, fast read-only queries
- **Storage Management**: Efficient LookupMap storage

## Tech Stack

- **Rust** 1.75+ - Systems programming language
- **near-sdk-rs** 5.0+ - NEAR smart contract SDK
- **NEAR Protocol** - Sharded, proof-of-stake blockchain
- **NEAR CLI** - Command-line interface

## Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Add wasm32 target
rustup target add wasm32-unknown-unknown

# Install NEAR CLI
npm install -g near-cli

# Verify installation
near --version  # Should be 4.0+
```

## Installation

```bash
cd languages/rust-near/donation-contract

# Build contract
cargo build --target wasm32-unknown-unknown --release

# Or use build.sh script
./build.sh

# Run tests
cargo test
```

## Contract Structure

### Storage

```rust
pub struct DonationContract {
    admin: AccountId,                              // Contract administrator
    total_donations: Balance,                      // Total NEAR received
    donor_amounts: LookupMap<AccountId, Balance>,  // Donor contributions
    donor_count: u64,                              // Number of unique donors
    min_donation: Balance,                         // Minimum (e.g., 0.01 NEAR)
    max_donation: Balance,                         // Maximum (e.g., 100 NEAR)
    paused: bool,                                  // Contract pause state
    initialized: bool,                             // Initialization flag
}
```

### Donor Tiers

| Tier | Minimum Donation | yoctoNEAR (10^-24) | Badge |
|------|-----------------|-------------------|-------|
| Bronze | 0.01 NEAR | 10^22 | 🥉 |
| Silver | 0.1 NEAR | 10^23 | 🥈 |
| Gold | 1 NEAR | 10^24 | 🥇 |
| Platinum | 10 NEAR | 10^25 | 💎 |

*Note: 1 NEAR = 10^24 yoctoNEAR*

## Usage

### Deploy Contract

```bash
# Create a NEAR account for the contract
near create-account donation.youraccount.testnet --masterAccount youraccount.testnet

# Deploy the contract
near deploy \
  --accountId donation.youraccount.testnet \
  --wasmFile target/wasm32-unknown-unknown/release/donation_contract.wasm

# Initialize the contract
near call donation.youraccount.testnet initialize \
  '{"admin": "youraccount.testnet", "min_donation": "10000000000000000000000", "max_donation": "100000000000000000000000000"}' \
  --accountId youraccount.testnet
```

### Make a Donation

```bash
# Donate 1 NEAR
near call donation.youraccount.testnet donate \
  --accountId donor.testnet \
  --amount 1
```

### Admin Operations

```bash
# Withdraw 0.5 NEAR to recipient
near call donation.youraccount.testnet withdraw \
  '{"amount": "500000000000000000000000", "recipient": "recipient.testnet"}' \
  --accountId youraccount.testnet

# Emergency withdrawal (all funds)
near call donation.youraccount.testnet emergency_withdraw \
  '{"recipient": "youraccount.testnet"}' \
  --accountId youraccount.testnet

# Pause contract
near call donation.youraccount.testnet pause \
  --accountId youraccount.testnet

# Unpause contract
near call donation.youraccount.testnet unpause \
  --accountId youraccount.testnet

# Update admin
near call donation.youraccount.testnet update_admin \
  '{"new_admin": "newadmin.testnet"}' \
  --accountId youraccount.testnet

# Update donation limits
near call donation.youraccount.testnet update_limits \
  '{"min_donation": "20000000000000000000000", "max_donation": "50000000000000000000000000"}' \
  --accountId youraccount.testnet
```

### Query Contract State (Free)

```bash
# Get total donations
near view donation.youraccount.testnet get_total_donations

# Get donor's contribution
near view donation.youraccount.testnet get_donor_amount \
  '{"donor": "donor.testnet"}'

# Get donor's tier
near view donation.youraccount.testnet get_donor_tier \
  '{"donor": "donor.testnet"}'

# Get donor count
near view donation.youraccount.testnet get_donor_count

# Check if paused
near view donation.youraccount.testnet is_paused

# Get admin
near view donation.youraccount.testnet get_admin

# Get contract balance
near view donation.youraccount.testnet get_balance

# Get comprehensive donor stats
near view donation.youraccount.testnet get_donor_stats \
  '{"donor": "donor.testnet"}'

# Get contract stats
near view donation.youraccount.testnet get_contract_stats
```

## Integration with JavaScript/TypeScript

### Install Dependencies

```bash
npm install near-api-js bn.js
```

### JavaScript Client

```typescript
import * as nearAPI from 'near-api-js';
const { connect, keyStores, WalletConnection, Contract } = nearAPI;

// Connect to NEAR
const config = {
  networkId: 'testnet',
  keyStore: new keyStores.BrowserLocalStorageKeyStore(),
  nodeUrl: 'https://rpc.testnet.near.org',
  walletUrl: 'https://wallet.testnet.near.org',
};

const near = await connect(config);
const wallet = new WalletConnection(near);

// Create contract instance
const contract = new Contract(
  wallet.account(),
  'donation.youraccount.testnet',
  {
    viewMethods: [
      'get_total_donations',
      'get_donor_amount',
      'get_donor_tier',
      'get_donor_count',
      'is_paused',
      'get_admin',
      'get_balance',
      'get_donor_stats',
      'get_contract_stats',
    ],
    changeMethods: [
      'initialize',
      'donate',
      'withdraw',
      'emergency_withdraw',
      'pause',
      'unpause',
      'update_admin',
      'update_limits',
    ],
  }
);

// Initialize contract
await contract.initialize({
  args: {
    admin: 'youraccount.testnet',
    min_donation: '10000000000000000000000',
    max_donation: '100000000000000000000000000',
  },
});

// Make donation (1 NEAR)
await contract.donate({
  args: {},
  amount: '1000000000000000000000000', // 1 NEAR in yoctoNEAR
  gas: '30000000000000',
});

// Query donor amount (free, no gas)
const amount = await contract.get_donor_amount({
  donor: 'donor.testnet',
});
console.log('Donor amount:', amount);
```

### React Integration

```typescript
import { useEffect, useState } from 'react';
import { Contract } from 'near-api-js';

function DonationApp({ wallet }) {
  const [contract, setContract] = useState(null);
  const [stats, setStats] = useState(null);

  useEffect(() => {
    if (wallet && wallet.isSignedIn()) {
      const contract = new Contract(
        wallet.account(),
        'donation.youraccount.testnet',
        {
          viewMethods: ['get_contract_stats'],
          changeMethods: ['donate'],
        }
      );
      setContract(contract);

      // Load stats
      contract.get_contract_stats().then(setStats);
    }
  }, [wallet]);

  const handleDonate = async (amount) => {
    await contract.donate({
      args: {},
      amount: (amount * 1e24).toString(),
      gas: '30000000000000',
    });
  };

  return (
    <div>
      <h1>Donation DApp</h1>
      {stats && (
        <div>
          <p>Total Donations: {stats.total_donations / 1e24} NEAR</p>
          <p>Donor Count: {stats.donor_count}</p>
        </div>
      )}
      <button onClick={() => handleDonate(1)}>
        Donate 1 NEAR
      </button>
    </div>
  );
}
```

## Testing

### Unit Tests

```bash
# Run unit tests
cargo test

# Run tests with output
cargo test -- --nocapture

# Run specific test
cargo test test_initialization -- --nocapture
```

### Integration Tests

Create a `tests/integration.sh` script:

```bash
#!/bin/bash

# Deploy contract
near deploy --accountId donation.test.near --wasmFile ./target/wasm32-unknown-unknown/release/donation_contract.wasm

# Initialize
near call donation.test.near initialize '{"admin": "admin.test.near", "min_donation": "10000000000000000000000", "max_donation": "100000000000000000000000000"}' --accountId admin.test.near

# Test donation
near call donation.test.near donate --accountId donor.test.near --amount 1

# Verify donation
near view donation.test.near get_donor_amount '{"donor": "donor.test.near"}'

echo "All tests passed!"
```

### Example Test

```rust
#[test]
fn test_donation_flow() {
    let context = get_context(accounts(0));
    testing_env!(context);

    let mut contract = DonationContract::new();

    // Initialize
    contract.initialize(
        accounts(0),
        U128(10_000_000_000_000_000_000_000),
        U128(100_000_000_000_000_000_000_000_000),
    );

    // Make donation
    let mut context = get_context(accounts(1));
    context.attached_deposit = 1_000_000_000_000_000_000_000_000; // 1 NEAR
    testing_env!(context);

    let tier = contract.donate();

    // Verify tier
    assert_eq!(tier, DonorTier::Gold);
}
```

## Events

Events are logged using `env::log_str()`:

### DonationReceived

```json
{
  "donor": "donor.testnet",
  "amount": "1000000000000000000000000",
  "total": "1000000000000000000000000",
  "tier": "Gold",
  "timestamp": 1234567890
}
```

### Withdrawal

```json
{
  "admin": "admin.testnet",
  "amount": "500000000000000000000000",
  "recipient": "recipient.testnet",
  "timestamp": 1234567890
}
```

## Security Features

1. **Access Control**: Admin-only privileged operations
2. **Pausable Pattern**: Emergency stop mechanism
3. **Donation Limits**: Min/max constraints
4. **Overflow Protection**: Checked arithmetic
5. **Input Validation**: Comprehensive assertions
6. **Event Logging**: Full audit trail
7. **Rust Safety**: Memory safety and type safety

## Gas Optimization

- Uses `LookupMap` for efficient storage (O(1) lookups)
- Minimal state modifications per transaction
- Event logging for off-chain indexing
- Optimized release build settings

## NEAR Advantages

| Feature | Benefit |
|---------|---------|
| Sharding | Horizontal scalability |
| Low Fees | ~$0.0001 per transaction |
| Fast Finality | 1-2 second confirmation |
| Human-Readable Addresses | user.near instead of hex |
| Progressive Security | Gradual onboarding |
| Built-in Features | Token standards, access keys |

## Why NEAR for Smart Contracts?

1. **Developer Experience**: Familiar languages (Rust, AssemblyScript)
2. **User Experience**: Human-readable addresses, progressive onboarding
3. **Performance**: Fast finality and high throughput
4. **Cost**: Very low transaction fees
5. **Scalability**: Dynamic sharding for unlimited scale
6. **Ecosystem**: Growing DeFi, NFT, and gaming projects

## Build Script

Create `build.sh`:

```bash
#!/bin/bash
set -e

# Build contract
cargo build --target wasm32-unknown-unknown --release

# Copy wasm file
cp target/wasm32-unknown-unknown/release/*.wasm ./res/

echo "✓ Contract built successfully"
```

## Deployment Checklist

- [ ] Build contract: `cargo build --target wasm32-unknown-unknown --release`
- [ ] Create NEAR account for contract
- [ ] Deploy contract: `near deploy`
- [ ] Initialize with correct admin and limits
- [ ] Test on testnet thoroughly
- [ ] Deploy to mainnet
- [ ] Verify contract functionality
- [ ] Document contract address

## Cost Estimation

NEAR transaction costs:

- **Deploy**: ~0.5 NEAR (one-time)
- **Storage**: ~0.0001 NEAR per 10KB
- **Donation call**: ~0.0003 NEAR gas
- **View calls**: Free!

## Advanced Features

### Batch Operations

```rust
#[near_bindgen]
impl DonationContract {
    pub fn batch_donate(&mut self, amounts: Vec<U128>) -> Vec<DonorTier> {
        amounts.iter().map(|_| self.donate()).collect()
    }
}
```

### Donation History

```rust
#[derive(BorshDeserialize, BorshSerialize)]
pub struct DonationRecord {
    amount: Balance,
    timestamp: u64,
}

donation_history: UnorderedMap<AccountId, Vec<DonationRecord>>,
```

### Refund Mechanism

```rust
pub fn request_refund(&mut self) -> Promise {
    let donor = env::predecessor_account_id();
    let amount = self.donor_amounts.get(&donor).expect("No donations");

    self.donor_amounts.remove(&donor);
    self.total_donations -= amount;

    Promise::new(donor).transfer(amount)
}
```

## Troubleshooting

### Build Errors

```bash
# Clean and rebuild
cargo clean
cargo build --target wasm32-unknown-unknown --release
```

### NEAR CLI Issues

```bash
# Login to NEAR
near login

# Check account
near state youraccount.testnet

# Check contract state
near state donation.youraccount.testnet
```

### Gas Issues

```bash
# Increase gas limit
near call CONTRACT_ID METHOD '{}' \
  --accountId ACCOUNT_ID \
  --gas 300000000000000
```

## Resources

- [NEAR Documentation](https://docs.near.org/) - Official NEAR docs
- [near-sdk-rs](https://github.com/near/near-sdk-rs) - Rust SDK
- [NEAR Examples](https://github.com/near-examples) - Example contracts
- [NEAR Explorer](https://explorer.near.org/) - Blockchain explorer
- [NEAR Wallet](https://wallet.near.org/) - Web wallet

## Mainnet Deployment

```bash
# Deploy to mainnet
near deploy \
  --accountId donation.near \
  --wasmFile target/wasm32-unknown-unknown/release/donation_contract.wasm \
  --networkId mainnet
```

## License

MIT License

## Contributing

Contributions are welcome! Please ensure:
- Code compiles without warnings
- Tests pass (`cargo test`)
- Follows Rust best practices
- Updates documentation
