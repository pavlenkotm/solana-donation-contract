# Motoko Donation Canister (Internet Computer / ICP)

A secure, actor-based donation canister written in Motoko for the Internet Computer Protocol (ICP), featuring cycles management and upgradeable state.

## Features

- **Actor Model**: Concurrent message passing architecture
- **Cycles Management**: Native ICP cycles handling for donations
- **Donor Tier System**: Automatic tier assignment (Bronze, Silver, Gold, Platinum)
- **Upgradeable**: Stable variables preserve state across upgrades
- **Access Control**: Admin-only privileged operations
- **Pausable**: Emergency stop mechanism
- **Query Functions**: Fast, free read-only operations
- **Type Safety**: Strong static typing with Motoko

## Tech Stack

- **Motoko** 0.10+ - Actor-based language for ICP
- **dfx** 0.15+ - Internet Computer SDK
- **ICP** - Internet Computer Protocol
- **Cycles** - ICP's gas mechanism

## Prerequisites

```bash
# Install dfx (Internet Computer SDK)
sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"

# Verify installation
dfx --version  # Should be 0.15.0+
```

## Installation

```bash
cd languages/motoko/donation-canister

# Start local replica
dfx start --background --clean

# Deploy canister
dfx deploy

# Stop replica when done
dfx stop
```

## Canister Structure

### State Variables

```motoko
admin: Principal              // Canister administrator
totalDonations: Nat          // Total cycles received
donorCount: Nat              // Number of unique donors
minDonation: Nat             // Minimum donation (e.g., 0.01 ICP)
maxDonation: Nat             // Maximum donation (e.g., 100 ICP)
paused: Bool                 // Canister pause state
initialized: Bool            // Initialization flag
```

### Stable Storage (for upgrades)

```motoko
donorAmounts: HashMap<Principal, Nat>       // Donor contributions
donorFirstDonation: HashMap<Principal, Int> // First donation timestamps
```

### Donor Tiers

| Tier | Minimum Donation | e8s (10^-8 ICP) | Badge |
|------|-----------------|-----------------|-------|
| Bronze | 0.01 ICP | 1,000,000 | 🥉 |
| Silver | 0.1 ICP | 10,000,000 | 🥈 |
| Gold | 1 ICP | 100,000,000 | 🥇 |
| Platinum | 10 ICP | 1,000,000,000 | 💎 |

*Note: 1 ICP = 10^8 e8s (smallest unit)*

## Usage

### Deploy Canister

```bash
# Deploy to local replica
dfx deploy donation

# Deploy to IC mainnet
dfx deploy --network ic donation

# Get canister ID
dfx canister id donation
```

### Initialize Canister

```bash
# Initialize with admin and limits
dfx canister call donation initialize \
  "(principal \"$(dfx identity get-principal)\", 1_000_000, 100_000_000_000)"
```

### Make a Donation

```bash
# Donate 1 ICP (100,000,000 cycles) from your identity
dfx canister call donation donate --with-cycles 100000000

# Or use dfx wallet
dfx wallet send $(dfx canister id donation) 100000000
```

### Admin Operations

```bash
# Withdraw cycles
dfx canister call donation withdraw \
  "(50_000_000, principal \"r7inp-6aaaa-aaaaa-aaabq-cai\")"

# Emergency withdrawal (all cycles)
dfx canister call donation emergencyWithdraw \
  "(principal \"$(dfx identity get-principal)\")"

# Pause canister
dfx canister call donation pause

# Unpause canister
dfx canister call donation unpause

# Update admin
dfx canister call donation updateAdmin \
  "(principal \"new-admin-principal-here\")"

# Update donation limits
dfx canister call donation updateLimits \
  "(2_000_000, 50_000_000_000)"
```

### Query Functions (Read-Only, Free)

```bash
# Get total donations
dfx canister call donation getTotalDonations

# Get donor's contribution
dfx canister call donation getDonorAmount \
  "(principal \"$(dfx identity get-principal)\")"

# Get donor's tier
dfx canister call donation getDonorTier \
  "(principal \"$(dfx identity get-principal)\")"

# Get donor count
dfx canister call donation getDonorCount

# Check if paused
dfx canister call donation isPaused

# Get admin
dfx canister call donation getAdmin

# Get canister balance
dfx canister call donation getBalance

# Get comprehensive donor stats
dfx canister call donation getDonorStats \
  "(principal \"$(dfx identity get-principal)\")"

# Get contract stats
dfx canister call donation getContractStats

# Get all donors
dfx canister call donation getAllDonors
```

## Integration with JavaScript/TypeScript

### Install Dependencies

```bash
npm install @dfinity/agent @dfinity/principal @dfinity/candid
```

### JavaScript Client

```typescript
import { Actor, HttpAgent } from '@dfinity/agent';
import { Principal } from '@dfinity/principal';

// Create agent
const agent = new HttpAgent({ host: 'https://ic0.app' });

// In development, fetch root key
if (process.env.NODE_ENV !== 'production') {
  await agent.fetchRootKey();
}

// Load canister interface
const idlFactory = ({ IDL }) => {
  const DonorTier = IDL.Variant({
    None: IDL.Null,
    Bronze: IDL.Null,
    Silver: IDL.Null,
    Gold: IDL.Null,
    Platinum: IDL.Null,
  });

  const Error = IDL.Variant({
    AlreadyInitialized: IDL.Null,
    NotInitialized: IDL.Null,
    NotAdmin: IDL.Null,
    ContractPaused: IDL.Null,
    DonationTooSmall: IDL.Null,
    DonationTooLarge: IDL.Null,
    InvalidLimits: IDL.Null,
    InsufficientBalance: IDL.Null,
    TransferFailed: IDL.Null,
  });

  return IDL.Service({
    initialize: IDL.Func([IDL.Principal, IDL.Nat, IDL.Nat], [IDL.Variant({ ok: IDL.Bool, err: Error })], []),
    donate: IDL.Func([], [IDL.Variant({ ok: DonorTier, err: Error })], []),
    getTotalDonations: IDL.Func([], [IDL.Nat], ['query']),
    getDonorAmount: IDL.Func([IDL.Principal], [IDL.Nat], ['query']),
    getDonorTier: IDL.Func([IDL.Principal], [DonorTier], ['query']),
    // ... other methods
  });
};

// Create actor
const canisterId = 'your-canister-id';
const donationCanister = Actor.createActor(idlFactory, {
  agent,
  canisterId,
});

// Initialize canister
const adminPrincipal = Principal.fromText('...');
await donationCanister.initialize(adminPrincipal, 1_000_000n, 100_000_000_000n);

// Make donation
const result = await donationCanister.donate();
console.log('Donation result:', result);

// Query donor amount (free, fast)
const amount = await donationCanister.getDonorAmount(myPrincipal);
console.log('Donor amount:', amount);
```

### React Integration

```typescript
import { AuthClient } from '@dfinity/auth-client';
import { Actor } from '@dfinity/agent';

// Authenticate user
const authClient = await AuthClient.create();
await authClient.login({
  identityProvider: 'https://identity.ic0.app',
  onSuccess: async () => {
    const identity = authClient.getIdentity();
    const agent = new HttpAgent({ identity });

    // Create actor with authenticated identity
    const donationCanister = Actor.createActor(idlFactory, {
      agent,
      canisterId,
    });

    // User can now make donations
    const result = await donationCanister.donate();
  },
});
```

## Upgrading Canister

Motoko supports upgradeable canisters with stable variables:

```bash
# Upgrade canister (preserves stable variables)
dfx deploy donation --mode upgrade

# Or reinstall (clears all state - use with caution!)
dfx deploy donation --mode reinstall
```

### Upgrade Process

1. `preupgrade` system function saves state to stable variables
2. Canister code is replaced
3. `postupgrade` system function restores state from stable variables

```motoko
system func preupgrade() {
  // Save to stable storage
  donorAmountsEntries := Iter.toArray(donorAmounts.entries());
};

system func postupgrade() {
  // Restore from stable storage
  donorAmounts := HashMap.fromIter(donorAmountsEntries.vals(), ...);
  donorAmountsEntries := [];
};
```

## Testing

### Unit Tests

Create `test/donation.test.mo`:

```motoko
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Donation "../main";

// Test initialization
let testPrincipal = Principal.fromText("2vxsx-fae");
let result = await Donation.initialize(testPrincipal, 1_000_000, 100_000_000);

switch (result) {
  case (#ok(success)) {
    Debug.print("✓ Initialization successful");
  };
  case (#err(e)) {
    Debug.print("✗ Initialization failed");
  };
};
```

### Integration Tests

```bash
# Deploy to local replica
dfx start --background --clean
dfx deploy

# Run test scripts
./test.sh

# Stop replica
dfx stop
```

### Example Test Script

```bash
#!/bin/bash

CANISTER_ID=$(dfx canister id donation)
ADMIN=$(dfx identity get-principal)

echo "Testing initialization..."
dfx canister call donation initialize "($ADMIN, 1_000_000, 100_000_000_000)"

echo "Testing donation..."
dfx canister call donation donate --with-cycles 100000000

echo "Checking donor amount..."
dfx canister call donation getDonorAmount "($ADMIN)"

echo "Checking donor tier..."
dfx canister call donation getDonorTier "($ADMIN)"

echo "All tests passed!"
```

## Error Handling

```motoko
type Error = {
  #AlreadyInitialized;   // Canister already initialized
  #NotInitialized;       // Canister not initialized
  #NotAdmin;             // Caller is not admin
  #ContractPaused;       // Canister is paused
  #DonationTooSmall;     // Donation below minimum
  #DonationTooLarge;     // Donation above maximum
  #InvalidLimits;        // Invalid min/max limits
  #InsufficientBalance;  // Not enough cycles
  #TransferFailed;       // Transfer operation failed
};
```

## Security Features

1. **Principal-Based Auth**: Identity verification via ICP principals
2. **Access Control**: Admin-only privileged operations
3. **Pausable Pattern**: Emergency stop mechanism
4. **Donation Limits**: Min/max constraints
5. **Type Safety**: Compile-time guarantees
6. **Upgrade Safety**: Stable variables preserve state
7. **Cycles Management**: Built-in resource management

## Motoko Advantages

| Feature | Benefit |
|---------|---------|
| Actor Model | Natural concurrency and scalability |
| Type Safety | Strong static typing prevents errors |
| Async/Await | Clean asynchronous programming |
| Stable Variables | Seamless upgrades with state preservation |
| Query Functions | Free, fast read operations |
| Cycles Management | Built-in resource management |

## Why Motoko for Smart Contracts?

1. **Web-Speed**: Query functions execute at web speed
2. **Upgradeability**: Seamless canister upgrades
3. **Type Safety**: Catch errors at compile time
4. **Async/Await**: Modern concurrency primitives
5. **ICP-Native**: Designed specifically for Internet Computer
6. **Developer Experience**: Familiar syntax, excellent tooling

## Advanced Features

### Custom Types

```motoko
type DonationHistory = {
  timestamp: Int;
  amount: Nat;
  tier: DonorTier;
};

private var donationHistory = HashMap.HashMap<Principal, [DonationHistory]>(10, Principal.equal, Principal.hash);
```

### Time-Based Rewards

```motoko
public query func getLoyaltyBonus(donor: Principal): async Nat {
  switch (donorFirstDonation.get(donor)) {
    case null { 0 };
    case (?firstTime) {
      let daysSince = (Time.now() - firstTime) / (86_400_000_000_000);
      if (daysSince > 100) { 10 } else { 0 } // 10% bonus after 100 days
    };
  };
};
```

### Batch Queries

```motoko
public query func getDonorsBatch(donors: [Principal]): async [(Principal, Nat, DonorTier)] {
  Array.map<Principal, (Principal, Nat, DonorTier)>(
    donors,
    func (donor) {
      let amount = Option.get(donorAmounts.get(donor), 0);
      (donor, amount, calculateTier(amount))
    }
  )
};
```

## Cycles Management

### Top Up Canister

```bash
# Add cycles to canister
dfx canister deposit-cycles 1000000000 donation
```

### Monitor Cycles

```bash
# Check canister balance
dfx canister status donation
```

### Auto Top-Up (in code)

```motoko
public func checkCyclesBalance(): async () {
  let balance = ExperimentalCycles.balance();
  if (balance < 1_000_000_000) {
    // Alert admin or request top-up
    Debug.print("Warning: Low cycles balance!");
  };
};
```

## Troubleshooting

### Build Errors

```bash
# Clean and rebuild
rm -rf .dfx
dfx start --clean --background
dfx deploy
```

### Cycles Issues

```bash
# Check wallet balance
dfx wallet balance

# Transfer cycles to wallet
dfx ledger top-up $(dfx wallet id) --amount 2.0
```

### Identity Issues

```bash
# Check current identity
dfx identity whoami

# Create new identity
dfx identity new myidentity

# Use identity
dfx identity use myidentity
```

## Resources

- [Motoko Documentation](https://internetcomputer.org/docs/current/motoko/main/getting-started/) - Official guide
- [Motoko Base Library](https://internetcomputer.org/docs/current/motoko/main/base/) - Standard library
- [dfx SDK](https://internetcomputer.org/docs/current/developer-docs/setup/install/) - Development kit
- [ICP Developer Portal](https://internetcomputer.org/docs) - Comprehensive docs
- [Motoko Playground](https://m7sm4-2iaaa-aaaab-qabra-cai.ic0.app/) - Online IDE

## Deployment Checklist

- [ ] Initialize canister with correct admin
- [ ] Set appropriate donation limits
- [ ] Test on local replica
- [ ] Deploy to IC mainnet
- [ ] Verify canister ID
- [ ] Fund canister with cycles
- [ ] Set up monitoring
- [ ] Document canister interface

## Cost Estimation

On Internet Computer, costs are in cycles:

- **Canister creation**: ~100B cycles (~$0.13)
- **Storage**: ~4T cycles/GB/year (~$5/GB/year)
- **Compute**: ~590K cycles/B of execution (~$0.0007/B)
- **Query calls**: Free!

## License

MIT License

## Contributing

Contributions are welcome! Please ensure:
- Code compiles with `dfx build`
- Tests pass
- Documentation is updated
- Follows Motoko best practices
