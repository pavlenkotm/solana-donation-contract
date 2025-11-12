# Clarity Donation Contract (Stacks - Bitcoin Layer 2)

A secure, decidable donation smart contract written in Clarity for the Stacks blockchain, bringing smart contracts to Bitcoin.

## Features

- **Bitcoin-Secured**: Leverages Bitcoin's security through Stacks
- **Decidable Language**: No recursion or reentrancy - analyzable at compile time
- **Donor Tier System**: Automatic tier assignment (Bronze, Silver, Gold, Platinum)
- **Access Control**: Admin-only privileged operations
- **Pausable**: Emergency stop mechanism
- **Event Logging**: Comprehensive print statements for analytics
- **STX Transfers**: Native Stacks token (STX) handling
- **Read-Only Views**: Gas-free state queries

## Tech Stack

- **Clarity** 2.4 - Decidable smart contract language
- **Clarinet** - Development and testing tool
- **Stacks** - Bitcoin Layer 2 blockchain
- **STX** - Native Stacks token

## Prerequisites

```bash
# Install Clarinet
curl -L https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-linux-x64.tar.gz -o clarinet.tar.gz
tar -xzf clarinet.tar.gz
sudo mv clarinet /usr/local/bin/

# Verify installation
clarinet --version  # Should be 2.0+
```

## Installation

```bash
cd languages/clarity/donation-contract

# Check contract syntax
clarinet check

# Run tests
clarinet test

# Open REPL for interactive testing
clarinet console
```

## Contract Structure

### Data Variables

```clarity
admin              ;; Contract administrator
total-donations    ;; Cumulative donation amount
donor-count        ;; Number of unique donors
min-donation       ;; Minimum donation (e.g., 10,000 microSTX = 0.01 STX)
max-donation       ;; Maximum donation (e.g., 100,000,000 microSTX = 100 STX)
paused             ;; Contract pause state
initialized        ;; Initialization flag
```

### Data Maps

```clarity
donor-amounts                ;; principal -> uint (total contribution)
donor-first-donation-block   ;; principal -> uint (first donation block)
```

### Donor Tiers

| Tier | Minimum Donation | microSTX | Badge |
|------|-----------------|----------|-------|
| Bronze | 0.01 STX | 10,000 | 🥉 |
| Silver | 0.1 STX | 100,000 | 🥈 |
| Gold | 1 STX | 1,000,000 | 🥇 |
| Platinum | 10 STX | 10,000,000 | 💎 |

*Note: 1 STX = 1,000,000 microSTX*

## Usage

### Initialize Contract

```clarity
;; Initialize with admin and donation limits
(contract-call? .donation initialize
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; admin address
  u10000                                        ;; min: 0.01 STX
  u100000000                                    ;; max: 100 STX
)
```

### Make a Donation

```clarity
;; Donate 1 STX (1,000,000 microSTX)
(contract-call? .donation donate u1000000)
```

### Admin Functions

```clarity
;; Withdraw 0.5 STX to recipient
(contract-call? .donation withdraw
  u500000                                         ;; amount
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG  ;; recipient
)

;; Emergency withdrawal (all funds)
(contract-call? .donation emergency-withdraw
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; recipient
)

;; Pause contract
(contract-call? .donation pause)

;; Unpause contract
(contract-call? .donation unpause)

;; Update admin
(contract-call? .donation update-admin
  'ST2NEWADMINADDRESS123456789ABCDEFGH
)

;; Update donation limits
(contract-call? .donation update-donation-limits
  u20000    ;; new min
  u50000000 ;; new max
)
```

### Query Functions (Read-Only)

```clarity
;; Get total donations
(contract-call? .donation get-total-donations)

;; Get donor's contribution
(contract-call? .donation get-donor-amount 'ST1...)

;; Get donor's tier
(contract-call? .donation get-donor-tier 'ST1...)

;; Get donor count
(contract-call? .donation get-donor-count)

;; Check if paused
(contract-call? .donation is-paused)

;; Get admin
(contract-call? .donation get-admin)

;; Get contract balance
(contract-call? .donation get-contract-balance)

;; Get comprehensive donor stats
(contract-call? .donation get-donor-stats 'ST1...)

;; Get contract stats
(contract-call? .donation get-contract-stats)
```

## Testing with Clarinet

### Console Testing

```bash
clarinet console
```

```clarity
;; In the Clarinet console

;; Initialize contract
(contract-call? .donation initialize tx-sender u10000 u100000000)

;; Simulate donation from wallet_1
::set_tx_sender wallet_1
(contract-call? .donation donate u1000000)

;; Check donor amount
(contract-call? .donation get-donor-amount tx-sender)

;; Check tier
(contract-call? .donation get-donor-tier tx-sender)

;; Admin operations
::set_tx_sender deployer
(contract-call? .donation withdraw u500000 'ST1...)
```

### Unit Tests

Create `tests/donation_test.ts`:

```typescript
import { Clarinet, Tx, Chain, Account } from 'https://deno.land/x/clarinet@v1.7.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Can initialize contract",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;

    let block = chain.mineBlock([
      Tx.contractCall(
        'donation',
        'initialize',
        [deployer.address, '10000', '100000000'],
        deployer.address
      )
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');
  },
});

Clarinet.test({
  name: "Can make donation and get correct tier",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      // Initialize
      Tx.contractCall(
        'donation',
        'initialize',
        [deployer.address, '10000', '100000000'],
        deployer.address
      ),
      // Donate 1 STX
      Tx.contractCall(
        'donation',
        'donate',
        ['1000000'],
        wallet1.address
      )
    ]);

    assertEquals(block.receipts[1].result, '(ok u3)'); // Gold tier
  },
});
```

Run tests:

```bash
clarinet test
```

## Deployment

### Deploy to Testnet

```bash
# Generate deployment plan
clarinet deployment generate --testnet

# Deploy
clarinet deployment apply --testnet
```

### Deploy to Mainnet

```bash
# Generate deployment plan
clarinet deployment generate --mainnet

# Review carefully, then deploy
clarinet deployment apply --mainnet
```

### Manual Deployment

```bash
# Using Stacks CLI
stx deploy_contract donation donation.clar \
  --testnet \
  --private-key <your-private-key>
```

## Integration with JavaScript/TypeScript

```typescript
import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  uintCV,
  standardPrincipalCV
} from '@stacks/transactions';
import { StacksTestnet } from '@stacks/network';

// Initialize contract
const txOptions = {
  contractAddress: 'ST1...',
  contractName: 'donation',
  functionName: 'initialize',
  functionArgs: [
    standardPrincipalCV('ST1ADMIN...'),
    uintCV(10000),
    uintCV(100000000)
  ],
  senderKey: privateKey,
  network: new StacksTestnet(),
  anchorMode: AnchorMode.Any,
};

const transaction = await makeContractCall(txOptions);
const broadcastResponse = await broadcastTransaction(transaction);

// Make donation
const donateOptions = {
  contractAddress: 'ST1...',
  contractName: 'donation',
  functionName: 'donate',
  functionArgs: [uintCV(1000000)],
  senderKey: donorPrivateKey,
  network: new StacksTestnet(),
  anchorMode: AnchorMode.Any,
};

const donateTx = await makeContractCall(donateOptions);
await broadcastTransaction(donateTx);

// Query donor amount (read-only)
import { callReadOnlyFunction } from '@stacks/transactions';

const result = await callReadOnlyFunction({
  contractAddress: 'ST1...',
  contractName: 'donation',
  functionName: 'get-donor-amount',
  functionArgs: [standardPrincipalCV('ST1DONOR...')],
  network: new StacksTestnet(),
  senderAddress: 'ST1...',
});

console.log('Donor amount:', result);
```

## Events / Print Statements

Clarity uses `print` statements for event logging:

### DonationReceived

```clarity
{
  event: "donation-received",
  donor: principal,
  amount: uint,
  total: uint,
  tier: uint,
  block-height: uint
}
```

### Withdrawal

```clarity
{
  event: "withdrawal",
  admin: principal,
  amount: uint,
  recipient: principal,
  block-height: uint
}
```

### ContractPaused

```clarity
{
  event: "contract-paused",
  admin: principal,
  block-height: uint
}
```

## Security Features

1. **Decidable**: No recursion or loops - all execution paths analyzable
2. **Post-Conditions**: Enforceable guarantees about state changes
3. **Access Control**: Admin-only functions
4. **Pausable Pattern**: Emergency stop
5. **Donation Limits**: Min/max constraints
6. **Explicit Errors**: Clear error codes
7. **Bitcoin Security**: Anchored to Bitcoin blockchain

## Clarity Advantages

| Feature | Benefit |
|---------|---------|
| Decidable | Predictable execution, no reentrancy |
| Bitcoin-Secured | Inherits Bitcoin's security |
| Read-Only Functions | Free queries, no gas cost |
| Post-Conditions | Enforceable guarantees |
| Explicit Errors | Clear error handling |
| No Compiler | Direct interpretation, no bytecode bugs |

## Why Clarity for Smart Contracts?

1. **Security First**: Designed to prevent common vulnerabilities
2. **Bitcoin Connection**: Smart contracts on Bitcoin's security layer
3. **Decidability**: All code paths are analyzable
4. **Simplicity**: Easy to audit and reason about
5. **Post-Conditions**: Mathematical guarantees about execution
6. **Read-Only Views**: Free queries for better UX

## Advanced Features

### Post-Conditions

Protect your transactions with post-conditions:

```typescript
import {
  makeContractSTXPostCondition,
  FungibleConditionCode,
  createAssetInfo
} from '@stacks/transactions';

const postConditions = [
  makeContractSTXPostCondition(
    contractAddress,
    contractName,
    FungibleConditionCode.Equal,
    1000000 // Exactly 1 STX must be transferred
  )
];

const txOptions = {
  // ... other options
  postConditions,
  postConditionMode: PostConditionMode.Deny,
};
```

### Analytics

```clarity
;; Get comprehensive stats
(contract-call? .donation get-contract-stats)
;; Returns:
;; {
;;   total-donations: uint,
;;   donor-count: uint,
;;   paused: bool,
;;   admin: principal,
;;   balance: uint
;; }

;; Get donor details
(contract-call? .donation get-donor-stats 'ST1...)
;; Returns:
;; {
;;   amount: uint,
;;   tier: uint,
;;   first-donation-block: (optional uint)
;; }
```

## Common Patterns

### Bulk Donations

```clarity
(define-public (bulk-donate (amounts (list 10 uint)))
  (fold donate-iter amounts (ok u0))
)
```

### Time-Based Rewards

```clarity
(define-read-only (get-loyalty-bonus (donor principal))
  (match (map-get? donor-first-donation-block donor)
    first-block
      (let ((blocks-since (- block-height first-block)))
        (if (> blocks-since u144000) ;; ~100 days
          u110 ;; 10% bonus
          u100
        )
      )
    u100
  )
)
```

## Troubleshooting

### Check Contract Errors

```bash
clarinet check
```

### Debug in Console

```bash
clarinet console
::get_block_height
::get_contracts_by_name
```

### Common Errors

- `err-owner-only (u100)`: Caller is not admin
- `err-not-initialized (u101)`: Contract not initialized
- `err-donation-too-small (u104)`: Below minimum donation
- `err-transfer-failed (u108)`: STX transfer failed

## Resources

- [Clarity Book](https://book.clarity-lang.org/) - Official documentation
- [Stacks Documentation](https://docs.stacks.co/) - Stacks blockchain guide
- [Clarinet](https://github.com/hirosystems/clarinet) - Development tool
- [Hiro Platform](https://www.hiro.so/) - Developer tools
- [Stacks Explorer](https://explorer.stacks.co/) - Blockchain explorer

## Stacks Explorer Integration

View your contract on:
- **Testnet**: https://explorer.hiro.so/?chain=testnet
- **Mainnet**: https://explorer.hiro.so/

## License

MIT License

## Contributing

Contributions are welcome! Please ensure:
- Code passes `clarinet check`
- Tests are included (`clarinet test`)
- Clear documentation
- Follows Clarity best practices
