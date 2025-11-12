# Plutus Donation Contract (Cardano)

A production-ready donation smart contract written in Plutus (Haskell) for Cardano, featuring UTXO-based architecture and eUTXO model.

## Features

- **eUTXO Model**: Leverages Cardano's extended UTXO architecture
- **Donor Tier System**: Automatic tier assignment based on contributions
- **Access Control**: Admin-only privileged operations via signature verification
- **Pausable**: Emergency stop mechanism
- **Type Safety**: Haskell's strong type system with compile-time guarantees
- **Deterministic**: Predictable transaction validation
- **On-Chain Logic**: All business logic verified on-chain

## Tech Stack

- **Plutus** V2 - Cardano's smart contract platform
- **Haskell** 8.10+ - Functional programming language
- **Cabal** - Haskell build tool
- **Cardano CLI** - Command-line interface
- **PlutusPrelude** - On-chain Haskell subset

## Prerequisites

```bash
# Install GHC and Cabal
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# Install Cardano node and CLI
# Follow instructions at https://developers.cardano.org/docs/get-started/installing-cardano-node/

# Verify installation
cabal --version
cardano-cli --version
```

## Installation

```bash
cd languages/haskell-plutus/donation-contract

# Update cabal
cabal update

# Build contract
cabal build

# Run tests
cabal test
```

## Contract Architecture

### Datum (On-Chain State)

```haskell
data DonationDatum = DonationDatum
    { ddTotalDonations :: Integer                        -- Total received
    , ddDonorAmounts   :: [(PaymentPubKeyHash, Integer)] -- Donor -> Amount mapping
    , ddDonorCount     :: Integer                        -- Unique donors
    , ddPaused         :: Bool                           -- Pause state
    }
```

### Redeemer (Actions)

```haskell
data DonationRedeemer
    = Donate Integer              -- Make donation
    | Withdraw Integer            -- Withdraw (admin)
    | EmergencyWithdraw           -- Withdraw all (admin)
    | Pause                       -- Pause contract
    | Unpause                     -- Unpause contract
```

### Parameters (Deployment Config)

```haskell
data DonationParams = DonationParams
    { dpAdmin       :: PaymentPubKeyHash  -- Admin public key hash
    , dpMinDonation :: Integer            -- Min: 10,000 lovelace (0.01 ADA)
    , dpMaxDonation :: Integer            -- Max: 100,000,000 lovelace (100 ADA)
    }
```

### Donor Tiers

| Tier | Minimum Donation | Lovelace | Badge |
|------|-----------------|----------|-------|
| Bronze | 0.01 ADA | 10,000 | 🥉 |
| Silver | 0.1 ADA | 100,000 | 🥈 |
| Gold | 1 ADA | 1,000,000 | 🥇 |
| Platinum | 10 ADA | 10,000,000 | 💎 |

*Note: 1 ADA = 1,000,000 lovelace*

## Usage

### Compile Contract

```bash
# Compile to Plutus Core
cabal run donation-contract-exe

# Generate script address
cardano-cli address build \
  --payment-script-file donation.plutus \
  --testnet-magic 1097911063 \
  --out-file donation.addr
```

### Deploy Contract

```bash
# Create initial UTxO with datum
cardano-cli transaction build \
  --tx-in <YOUR_UTXO> \
  --tx-out "$(cat donation.addr)+2000000" \
  --tx-out-datum-hash-file initial-datum.json \
  --change-address $(cat payment.addr) \
  --testnet-magic 1097911063 \
  --out-file tx.raw

# Sign transaction
cardano-cli transaction sign \
  --tx-body-file tx.raw \
  --signing-key-file payment.skey \
  --testnet-magic 1097911063 \
  --out-file tx.signed

# Submit transaction
cardano-cli transaction submit \
  --tx-file tx.signed \
  --testnet-magic 1097911063
```

### Make a Donation

```bash
# Build donation transaction
cardano-cli transaction build \
  --tx-in <CONTRACT_UTXO> \
  --tx-in <DONOR_UTXO> \
  --tx-in-script-file donation.plutus \
  --tx-in-datum-file current-datum.json \
  --tx-in-redeemer-file donate-redeemer.json \
  --tx-out "$(cat donation.addr)+<NEW_AMOUNT>" \
  --tx-out-datum-hash-file new-datum.json \
  --change-address $(cat donor.addr) \
  --testnet-magic 1097911063 \
  --protocol-params-file protocol.json \
  --out-file donate-tx.raw

# Sign and submit
cardano-cli transaction sign \
  --tx-body-file donate-tx.raw \
  --signing-key-file donor.skey \
  --testnet-magic 1097911063 \
  --out-file donate-tx.signed

cardano-cli transaction submit \
  --tx-file donate-tx.signed \
  --testnet-magic 1097911063
```

### Admin Operations

#### Withdraw

Create `withdraw-redeemer.json`:
```json
{
  "constructor": 1,
  "fields": [
    {"int": 1000000}
  ]
}
```

#### Pause

Create `pause-redeemer.json`:
```json
{
  "constructor": 3,
  "fields": []
}
```

## Integration with JavaScript/TypeScript

```typescript
import {
  Lucid,
  Blockfrost,
  Data,
  fromText,
  toHex,
} from 'lucid-cardano';

// Initialize Lucid
const lucid = await Lucid.new(
  new Blockfrost('https://cardano-testnet.blockfrost.io/api/v0', 'YOUR_API_KEY'),
  'Testnet'
);

// Define schema
const DonationDatum = Data.Object({
  totalDonations: Data.Integer(),
  donorAmounts: Data.Array(Data.Tuple([Data.Bytes(), Data.Integer()])),
  donorCount: Data.Integer(),
  paused: Data.Boolean(),
});

const DonationRedeemer = Data.Enum([
  Data.Object({ Donate: Data.Integer() }),
  Data.Object({ Withdraw: Data.Integer() }),
  Data.Literal('EmergencyWithdraw'),
  Data.Literal('Pause'),
  Data.Literal('Unpause'),
]);

// Make donation
const scriptAddress = 'addr_test1...';
const redeemer = Data.to(new Constr(0, [1000000n])); // Donate 1 ADA

const tx = await lucid
  .newTx()
  .collectFrom([utxo], redeemer)
  .payToContract(scriptAddress, newDatum, { lovelace: 3000000n })
  .complete();

const signedTx = await tx.sign().complete();
const txHash = await signedTx.submit();
```

## Validator Logic

### Donation Validation

```haskell
Donate amount ->
    traceIfFalse "Contract is paused" (not $ ddPaused datum) &&
    traceIfFalse "Donation too small" (amount >= dpMinDonation params) &&
    traceIfFalse "Donation too large" (amount <= dpMaxDonation params) &&
    traceIfFalse "Incorrect output datum" checkDonateOutput
```

### Admin Validation

```haskell
Withdraw amount ->
    traceIfFalse "Not admin" isAdmin &&
    traceIfFalse "Invalid withdrawal amount" (amount > 0)
```

## Testing

### Unit Tests

```haskell
import Test.Tasty
import Test.Tasty.HUnit
import PlutusTx.Prelude

tests :: TestTree
tests = testGroup "Donation Contract Tests"
    [ testCase "Calculate Bronze tier" $
        calculateTier 10_000 @?= Bronze

    , testCase "Calculate Platinum tier" $
        calculateTier 10_000_000 @?= Platinum

    , testCase "Update donor amount" $ do
        let donors = [(testPkh, 100)]
        let updated = updateDonorAmount testPkh 200 donors
        getDonorAmount testPkh updated @?= 200
    ]
```

### Property Tests

```haskell
prop_tierMonotonic :: Integer -> Integer -> Property
prop_tierMonotonic amt1 amt2 =
    amt1 <= amt2 ==>
    tierValue (calculateTier amt1) <= tierValue (calculateTier amt2)
  where
    tierValue None = 0
    tierValue Bronze = 1
    tierValue Silver = 2
    tierValue Gold = 3
    tierValue Platinum = 4
```

## Security Features

1. **Validator Logic**: All business logic executed on-chain
2. **Type Safety**: Haskell's type system prevents errors
3. **Deterministic**: Same inputs always produce same outputs
4. **Admin Verification**: Signature-based access control
5. **Donation Limits**: Min/max constraints enforced
6. **Pause Mechanism**: Emergency stop functionality
7. **UTxO Model**: No shared state, no race conditions

## Plutus Advantages

| Feature | Benefit |
|---------|---------|
| Deterministic | Predictable execution costs |
| Type Safety | Compile-time guarantees |
| Formal Verification | Mathematical proofs possible |
| No Gas Wars | Fixed transaction costs |
| UTxO Model | Parallel transaction processing |
| Haskell | Mature ecosystem and tooling |

## Why Plutus for Smart Contracts?

1. **Security**: Formal verification and strong typing
2. **Predictability**: Deterministic execution and costs
3. **Scalability**: UTxO model enables parallelization
4. **Academic Rigor**: Peer-reviewed research foundation
5. **Haskell Ecosystem**: Access to mature libraries
6. **Cardano's Features**: Native tokens, multi-asset support

## Advanced Features

### Multi-Signature Admin

```haskell
data DonationParams = DonationParams
    { dpAdmins      :: [PaymentPubKeyHash]  -- Multiple admins
    , dpMinSignatures :: Integer             -- Required signatures
    , ...
    }
```

### Time-Locked Withdrawals

```haskell
Withdraw amount ->
    traceIfFalse "Not admin" isAdmin &&
    traceIfFalse "Too early" (txInfoValidRange info `contains` validTimeRange)
```

### Donation Matching

```haskell
data DonationRedeemer = ... | MatchDonation Integer Integer
```

## Troubleshooting

### Compilation Errors

```bash
# Clean build
cabal clean
cabal build

# Update dependencies
cabal update
cabal build --upgrade-dependencies
```

### Script Size

```bash
# Check script size
ls -lh donation.plutus

# Optimize (if > 16KB, consider splitting logic)
```

### Transaction Failures

```bash
# Check UTxO at script address
cardano-cli query utxo --address $(cat donation.addr) --testnet-magic 1097911063

# Verify datum hash
cardano-cli transaction hash-script-data --script-data-file datum.json
```

## Resources

- [Plutus Documentation](https://plutus.readthedocs.io/) - Official guide
- [Cardano Docs](https://developers.cardano.org/) - Developer resources
- [Plutus Pioneer Program](https://github.com/input-output-hk/plutus-pioneer-program) - Learning materials
- [Lucid](https://lucid.spacebudz.io/) - JavaScript library
- [Cardano Explorer](https://explorer.cardano.org/) - Blockchain explorer

## Mainnet Deployment

```bash
# Build for mainnet
cardano-cli address build \
  --payment-script-file donation.plutus \
  --mainnet \
  --out-file donation-mainnet.addr

# Deploy with appropriate collateral
# Ensure you have thoroughly tested on testnet first!
```

## License

MIT License

## Contributing

Contributions welcome! Please ensure:
- Code compiles without warnings
- Property tests pass
- Documentation is complete
- Follows Plutus best practices
