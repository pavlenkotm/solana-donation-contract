# Cairo Donation Contract (StarkNet)

A secure, production-ready donation smart contract written in Cairo for StarkNet, leveraging zero-knowledge proofs for scalability and privacy.

## Features

- **Donor Tier System**: Automatic tier assignment (Bronze, Silver, Gold, Platinum)
- **Access Control**: Admin-only functions for contract management
- **Pausable**: Emergency pause mechanism for security
- **Event Emission**: Comprehensive event logging for transparency
- **Withdrawal Management**: Partial and emergency withdrawal support
- **Donation Limits**: Configurable min/max donation amounts

## Tech Stack

- **Cairo** 2.5.0+ - StarkNet's native smart contract language
- **Scarb** - Cairo package manager
- **Starknet Foundry** - Testing and deployment tools
- **StarkNet** - Ethereum Layer 2 with zero-knowledge proofs

## Prerequisites

```bash
# Install Scarb (Cairo package manager)
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Verify installation
scarb --version  # Should be 2.5.0+
```

## Installation

```bash
cd languages/cairo/donation-contract

# Build the contract
scarb build

# Run tests
scarb test
```

## Contract Structure

### Storage Variables

- `admin`: Contract administrator address
- `total_donations`: Cumulative donation amount
- `donor_amounts`: Mapping of donor addresses to their total contributions
- `donor_count`: Number of unique donors
- `min_donation`: Minimum allowed donation (e.g., 0.01 ETH)
- `max_donation`: Maximum allowed donation (e.g., 100 ETH)
- `paused`: Contract pause state
- `initialized`: Initialization flag

### Donor Tiers

| Tier | Minimum Donation | Badge |
|------|-----------------|-------|
| Bronze | 0.01 ETH | 🥉 |
| Silver | 0.1 ETH | 🥈 |
| Gold | 1 ETH | 🥇 |
| Platinum | 10 ETH | 💎 |

## Usage

### Initialize Contract

```cairo
use donation_contract::IDonationContractDispatcher;
use donation_contract::IDonationContractDispatcherTrait;

// Initialize with admin and limits
contract.initialize(
    admin: admin_address,
    min_donation: 10000000000000000,  // 0.01 ETH in wei
    max_donation: 100000000000000000000,  // 100 ETH in wei
);
```

### Make a Donation

```cairo
// Donate ETH (amount sent with transaction)
let success = contract.donate();
```

### Admin Functions

```cairo
// Withdraw funds
contract.withdraw(
    amount: 1000000000000000000,  // 1 ETH
    recipient: recipient_address
);

// Emergency withdrawal (all funds)
contract.emergency_withdraw(recipient: admin_address);

// Pause contract
contract.pause();

// Unpause contract
contract.unpause();
```

### Query Functions

```cairo
// Get total donations
let total = contract.get_total_donations();

// Get donor's contribution
let amount = contract.get_donor_amount(donor_address);

// Get donor's tier (0-4)
let tier = contract.get_donor_tier(donor_address);

// Check if paused
let paused = contract.is_paused();

// Get admin address
let admin = contract.get_admin();
```

## Deployment

### Deploy to Testnet

```bash
# Declare the contract
starkli declare target/dev/donation_contract_DonationContract.contract_class.json \
  --account ~/.starkli-wallets/account.json \
  --keystore ~/.starkli-wallets/keystore.json

# Deploy the contract
starkli deploy <CLASS_HASH> \
  --account ~/.starkli-wallets/account.json \
  --keystore ~/.starkli-wallets/keystore.json
```

### Verify on Explorer

Visit [Voyager](https://voyager.online/) or [StarkScan](https://starkscan.co/) to verify your deployed contract.

## Testing

```bash
# Run all tests
scarb test

# Run specific test
scarb test test_donate

# Run tests with gas profiling
scarb test --gas
```

### Example Test

```cairo
#[test]
fn test_donate() {
    let contract = deploy_contract();

    // Initialize
    contract.initialize(admin(), 10_000_000_000_000_000, 100_000_000_000_000_000_000);

    // Donate
    let success = contract.donate();
    assert(success, 'Donation failed');

    // Verify donation
    let total = contract.get_total_donations();
    assert(total > 0, 'Total should be > 0');
}
```

## Events

### DonationReceived

Emitted when a donation is made.

```cairo
struct DonationReceived {
    donor: ContractAddress,
    amount: u128,
    total: u128,
    tier: u8,
    timestamp: u64,
}
```

### Withdrawal

Emitted when admin withdraws funds.

```cairo
struct Withdrawal {
    admin: ContractAddress,
    amount: u128,
    recipient: ContractAddress,
    timestamp: u64,
}
```

### ContractPaused / ContractUnpaused

Emitted when contract is paused/unpaused.

## Security Features

1. **Access Control**: Only admin can withdraw or pause
2. **Pausable Pattern**: Emergency stop mechanism
3. **Donation Limits**: Min/max constraints prevent abuse
4. **Initialization Guard**: Prevents re-initialization
5. **Event Logging**: Full audit trail
6. **Cairo's Safety**: Built-in overflow protection and type safety

## Gas Optimization

- Uses `LegacyMap` for efficient storage
- Event emission for off-chain indexing
- Minimal storage updates per transaction

## Cairo Advantages for Smart Contracts

1. **ZK-Proofs**: Native zero-knowledge proof support
2. **Scalability**: L2 rollup with low fees
3. **Safety**: Strong type system and provable correctness
4. **Efficiency**: Optimized for STARK proof generation
5. **Ecosystem**: Growing DeFi and NFT ecosystem on StarkNet

## Common Operations

### Check Donor Tier

```cairo
let tier = contract.get_donor_tier(donor_address);

match tier {
    0 => println!("No donations yet"),
    1 => println!("Bronze donor 🥉"),
    2 => println!("Silver donor 🥈"),
    3 => println!("Gold donor 🥇"),
    4 => println!("Platinum donor 💎"),
    _ => println!("Invalid tier"),
}
```

### Monitor Donations

```cairo
// Listen to DonationReceived events
let events = contract.get_events();
for event in events {
    if let Event::DonationReceived(e) = event {
        println!("Donor: {}, Amount: {}", e.donor, e.amount);
    }
}
```

## Resources

- [Cairo Book](https://book.cairo-lang.org/) - Official Cairo documentation
- [StarkNet Book](https://book.starknet.io/) - StarkNet guide
- [Scarb Documentation](https://docs.swmansion.com/scarb/) - Package manager
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) - Testing framework
- [Cairo by Example](https://cairo-by-example.com/) - Code examples

## Why Cairo?

| Feature | Benefit |
|---------|---------|
| ZK-Native | Built for zero-knowledge proofs from the ground up |
| Low Fees | L2 rollup drastically reduces transaction costs |
| Security | Provable correctness and mathematical guarantees |
| Scalability | High throughput with L2 aggregation |
| Ethereum Compatible | Easy bridge to Ethereum mainnet |

## Advanced Features

### Custom Tier Logic

Extend the contract with custom tier calculations:

```cairo
fn calculate_vip_tier(self: @ContractState, amount: u128, frequency: u32) -> u8 {
    // Custom logic based on amount and donation frequency
    if amount >= 50 * ETH_DECIMALS && frequency >= 10 {
        5  // VIP tier
    } else {
        self.calculate_tier(amount)
    }
}
```

### Multi-Token Support

Extend to support multiple ERC-20 tokens:

```cairo
#[storage]
struct Storage {
    // ... existing storage
    supported_tokens: LegacyMap<ContractAddress, bool>,
    token_balances: LegacyMap<(ContractAddress, ContractAddress), u128>,
}
```

## Troubleshooting

### Build Errors

```bash
# Clear build cache
scarb clean

# Rebuild
scarb build
```

### Test Failures

```bash
# Run tests with verbose output
scarb test --verbose

# Run single test with debugging
scarb test test_name --exact
```

## License

MIT License

## Contributing

Contributions are welcome! Please follow Cairo best practices and include tests for new features.
