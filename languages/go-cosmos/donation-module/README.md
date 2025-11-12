# Go Donation Module (Cosmos SDK)

A production-ready donation module written in Go for Cosmos SDK, enabling custom blockchain creation with built-in donation functionality and IBC support.

## Features

- **Cosmos SDK Module**: Pluggable module for any Cosmos chain
- **IBC Compatible**: Cross-chain donation support via Inter-Blockchain Communication
- **Donor Tier System**: Automatic tier assignment (Bronze, Silver, Gold, Platinum)
- **Access Control**: Admin-only privileged operations
- **Pausable**: Emergency stop mechanism
- **Event Emission**: Comprehensive blockchain event logging
- **State Management**: Efficient KVStore-based state storage
- **Query Support**: gRPC and REST API endpoints

## Tech Stack

- **Go** 1.21+ - Systems programming language
- **Cosmos SDK** 0.47+ - Blockchain application framework
- **CometBFT** 0.37+ (formerly Tendermint) - Consensus engine
- **Protocol Buffers** - Interface definition
- **gRPC** - RPC framework

## Prerequisites

```bash
# Install Go
wget https://go.dev/dl/go1.21.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Verify installation
go version  # Should be 1.21+
```

## Installation

```bash
cd languages/go-cosmos/donation-module

# Download dependencies
go mod download

# Build
go build

# Run tests
go test ./...
```

## Module Structure

### Keeper (State Management)

```go
type Keeper struct {
    cdc      codec.BinaryCodec
    storeKey storetypes.StoreKey
}
```

### State

```go
type DonationState struct {
    Admin          string
    TotalDonations sdk.Coins
    DonorCount     uint64
    MinDonation    sdk.Coins
    MaxDonation    sdk.Coins
    Paused         bool
    Initialized    bool
}
```

### Donor Record

```go
type DonorRecord struct {
    Address       string
    TotalDonated  sdk.Coins
    Tier          DonorTier
    FirstDonation int64
}
```

### Donor Tiers

| Tier | Minimum Donation | uatom (10^-6) | Badge |
|------|-----------------|---------------|-------|
| Bronze | 0.01 ATOM | 10,000 | 🥉 |
| Silver | 0.1 ATOM | 100,000 | 🥈 |
| Gold | 1 ATOM | 1,000,000 | 🥇 |
| Platinum | 10 ATOM | 10,000,000 | 💎 |

*Note: 1 ATOM = 1,000,000 uatom*

## Usage

### Integration into Cosmos Chain

```go
import (
    donationkeeper "github.com/donation-contract/cosmos-donation/keeper"
    donationtypes "github.com/donation-contract/cosmos-donation/types"
)

// In app.go
app.DonationKeeper = donationkeeper.NewKeeper(
    appCodec,
    keys[donationtypes.StoreKey],
)

// Register module
app.mm = module.NewManager(
    // ... other modules
    donation.NewAppModule(appCodec, app.DonationKeeper),
)
```

### CLI Commands

```bash
# Initialize module
mychaind tx donation initialize \
  cosmos1admin... \
  10000uatom \
  100000000uatom \
  --from admin \
  --chain-id mychain-1

# Make donation
mychaind tx donation donate \
  1000000uatom \
  --from donor \
  --chain-id mychain-1

# Withdraw (admin only)
mychaind tx donation withdraw \
  500000uatom \
  cosmos1recipient... \
  --from admin \
  --chain-id mychain-1

# Pause (admin only)
mychaind tx donation pause \
  --from admin \
  --chain-id mychain-1

# Unpause (admin only)
mychaind tx donation unpause \
  --from admin \
  --chain-id mychain-1
```

### Query Commands

```bash
# Get state
mychaind query donation state

# Get donor info
mychaind query donation donor cosmos1donor...

# Get all donors
mychaind query donation donors

# Get total donations
mychaind query donation total
```

## gRPC/REST Integration

### gRPC Client (Go)

```go
import (
    "context"
    "google.golang.org/grpc"
    donationtypes "github.com/donation-contract/cosmos-donation/types"
)

// Connect to gRPC
conn, err := grpc.Dial("localhost:9090", grpc.WithInsecure())
defer conn.Close()

client := donationtypes.NewQueryClient(conn)

// Query state
res, err := client.State(context.Background(), &donationtypes.QueryStateRequest{})
fmt.Println("Total donations:", res.State.TotalDonations)

// Query donor
donorRes, err := client.Donor(context.Background(), &donationtypes.QueryDonorRequest{
    Address: "cosmos1donor...",
})
fmt.Println("Donor tier:", donorRes.Donor.Tier)
```

### REST API

```bash
# Query state
curl http://localhost:1317/donation/v1/state

# Query donor
curl http://localhost:1317/donation/v1/donor/cosmos1donor...

# Query all donors
curl http://localhost:1317/donation/v1/donors
```

### JavaScript/TypeScript Client

```typescript
import { SigningStargateClient } from '@cosmjs/stargate';
import { stringToPath } from '@cosmjs/crypto';

// Connect to chain
const client = await SigningStargateClient.connectWithSigner(
  'http://localhost:26657',
  wallet,
);

// Make donation
const msg = {
  typeUrl: '/donation.MsgDonate',
  value: {
    donor: 'cosmos1donor...',
    amount: [{ denom: 'uatom', amount: '1000000' }],
  },
};

const result = await client.signAndBroadcast(
  'cosmos1donor...',
  [msg],
  'auto'
);

// Query donation state
const res = await client.queryContractSmart(contractAddress, {
  get_state: {},
});
console.log('Total donations:', res.total_donations);
```

## Events

### DonationReceived

```json
{
  "type": "donation_received",
  "attributes": [
    {"key": "donor", "value": "cosmos1donor..."},
    {"key": "amount", "value": "1000000uatom"},
    {"key": "total", "value": "1000000uatom"},
    {"key": "tier", "value": "3"},
    {"key": "timestamp", "value": "1234567890"}
  ]
}
```

### Withdrawal

```json
{
  "type": "withdrawal",
  "attributes": [
    {"key": "admin", "value": "cosmos1admin..."},
    {"key": "amount", "value": "500000uatom"},
    {"key": "recipient", "value": "cosmos1recipient..."},
    {"key": "timestamp", "value": "1234567890"}
  ]
}
```

## Testing

### Unit Tests

```go
func TestDonate(t *testing.T) {
    ctx, keeper := setupKeeper(t)

    // Initialize
    err := keeper.Initialize(
        ctx,
        "cosmos1admin",
        sdk.NewCoins(sdk.NewCoin("uatom", sdk.NewInt(10000))),
        sdk.NewCoins(sdk.NewCoin("uatom", sdk.NewInt(100000000))),
    )
    require.NoError(t, err)

    // Donate
    err = keeper.Donate(
        ctx,
        "cosmos1donor",
        sdk.NewCoins(sdk.NewCoin("uatom", sdk.NewInt(1000000))),
    )
    require.NoError(t, err)

    // Verify donor
    donor, found := keeper.GetDonor(ctx, "cosmos1donor")
    require.True(t, found)
    require.Equal(t, TierGold, donor.Tier)
}
```

### Integration Tests

```bash
# Start local chain
mychaind start

# Run integration tests
go test ./tests/integration/...
```

## IBC Cross-Chain Donations

```go
// Send donation to another Cosmos chain via IBC
func (k Keeper) IBCDonate(
    ctx sdk.Context,
    donor string,
    amount sdk.Coins,
    destChain string,
    destContract string,
) error {
    // Create IBC transfer
    msg := ibctransfertypes.NewMsgTransfer(
        "transfer",
        "channel-0",
        amount[0],
        donor,
        destContract,
        timeoutHeight,
        timeoutTimestamp,
    )

    // Execute transfer
    _, err := k.ibcKeeper.Transfer(ctx, msg)
    return err
}
```

## Security Features

1. **Admin Access Control**: Only admin can perform privileged operations
2. **Pausable Pattern**: Emergency stop mechanism
3. **Donation Limits**: Min/max constraints enforced
4. **Input Validation**: Comprehensive error checking
5. **Event Logging**: Full audit trail
6. **KVStore Isolation**: Module state is isolated
7. **IBC Security**: Leverages Cosmos IBC security guarantees

## Cosmos SDK Advantages

| Feature | Benefit |
|---------|---------|
| Modularity | Pluggable module architecture |
| IBC | Native cross-chain communication |
| Consensus | Battle-tested CometBFT consensus |
| Developer Tools | Rich ecosystem and tooling |
| Governance | On-chain governance support |
| Staking | Built-in token staking |

## Why Cosmos SDK for Blockchain?

1. **Interoperability**: IBC enables cross-chain communication
2. **Sovereignty**: Application-specific blockchains
3. **Scalability**: Horizontal scaling via IBC zones
4. **Developer Experience**: Modular, well-documented
5. **Performance**: Fast finality (~7 seconds)
6. **Ecosystem**: Growing network of interconnected chains

## Module Architecture

```
donation-module/
├── keeper.go          # State management logic
├── types/
│   ├── genesis.go     # Genesis state
│   ├── keys.go        # Store keys
│   ├── msgs.go        # Transaction messages
│   └── query.proto    # Query definitions
├── handler.go         # Message routing
├── genesis.go         # Genesis initialization
└── module.go          # Module interface
```

## Protocol Buffer Definitions

Create `proto/donation/v1/tx.proto`:

```protobuf
syntax = "proto3";

package donation.v1;

import "cosmos/base/v1beta1/coin.proto";
import "gogoproto/gogo.proto";

service Msg {
  rpc Initialize(MsgInitialize) returns (MsgInitializeResponse);
  rpc Donate(MsgDonate) returns (MsgDonateResponse);
  rpc Withdraw(MsgWithdraw) returns (MsgWithdrawResponse);
  rpc Pause(MsgPause) returns (MsgPauseResponse);
  rpc Unpause(MsgUnpause) returns (MsgUnpauseResponse);
}

message MsgDonate {
  string donor = 1;
  repeated cosmos.base.v1beta1.Coin amount = 2 [
    (gogoproto.nullable) = false,
    (gogoproto.castrepeated) = "github.com/cosmos/cosmos-sdk/types.Coins"
  ];
}
```

## Advanced Features

### Governance Integration

```go
// Propose donation limit update
func (k Keeper) SubmitLimitProposal(
    ctx sdk.Context,
    proposer string,
    newMin sdk.Coins,
    newMax sdk.Coins,
) error {
    // Create governance proposal
    content := NewLimitUpdateProposal(newMin, newMax)
    return k.govKeeper.SubmitProposal(ctx, content)
}
```

### Staking Rewards for Donors

```go
// Calculate staking rewards based on donor tier
func (k Keeper) CalculateDonorRewards(ctx sdk.Context, donor string) sdk.Coins {
    record, _ := k.GetDonor(ctx, donor)

    multiplier := map[DonorTier]sdk.Dec{
        TierBronze:   sdk.NewDecWithPrec(105, 2), // 1.05x
        TierSilver:   sdk.NewDecWithPrec(110, 2), // 1.10x
        TierGold:     sdk.NewDecWithPrec(120, 2), // 1.20x
        TierPlatinum: sdk.NewDecWithPrec(150, 2), // 1.50x
    }[record.Tier]

    return baseRewards.MulDec(multiplier)
}
```

## Deployment Checklist

- [ ] Define module in app.go
- [ ] Register gRPC queries
- [ ] Add CLI commands
- [ ] Configure genesis state
- [ ] Test on local chain
- [ ] Deploy to testnet
- [ ] Verify functionality
- [ ] Document module interface
- [ ] Deploy to mainnet

## Troubleshooting

### Build Errors

```bash
# Update dependencies
go mod tidy
go mod download

# Clean and rebuild
go clean
go build
```

### State Inconsistency

```bash
# Reset chain state
mychaind unsafe-reset-all

# Export state
mychaind export > genesis.json
```

## Resources

- [Cosmos SDK Documentation](https://docs.cosmos.network/) - Official docs
- [Cosmos SDK GitHub](https://github.com/cosmos/cosmos-sdk) - Source code
- [IBC Documentation](https://ibc.cosmos.network/) - IBC protocol
- [CosmWasm](https://cosmwasm.com/) - Smart contracts for Cosmos
- [Cosmos Hub](https://hub.cosmos.network/) - Main Cosmos chain

## Example Chains Using Cosmos SDK

- **Cosmos Hub** - ATOM
- **Osmosis** - DEX
- **Juno** - Smart contracts
- **Celestia** - Data availability
- **dYdX** - Derivatives
- **Injective** - DeFi

## License

MIT License

## Contributing

Contributions are welcome! Please ensure:
- Code passes `go vet` and `golint`
- Tests pass (`go test ./...`)
- Documentation is updated
- Follows Cosmos SDK best practices
