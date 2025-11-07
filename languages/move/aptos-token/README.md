# 🎯 Move Smart Contract - Aptos Token

A professional token implementation in Move language for the Aptos blockchain.

## 🌟 Overview

Move is a next-generation smart contract language designed for safety and flexibility. Originally developed for Diem (Facebook's blockchain), it's now used by Aptos and Sui blockchains.

## ✨ Features

- **Resource-Oriented**: Move's unique resource model prevents duplication and loss
- **Type Safety**: Strong static typing with generics
- **Formal Verification**: Built-in verification capabilities
- **Coin Standard**: Implements Aptos coin standard
- **Mint & Burn**: Full lifecycle management
- **View Functions**: Gas-free balance and metadata queries
- **Comprehensive Tests**: Built-in unit tests

## 🛠️ Tech Stack

- **Move** language
- **Aptos Framework** (mainnet)
- **Aptos CLI** for deployment and testing

## 📋 Prerequisites

```bash
# Install Aptos CLI
curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3

# Verify installation
aptos --version
```

## 🚀 Installation & Setup

```bash
cd languages/move/aptos-token

# Initialize Aptos account (if needed)
aptos init

# Compile the module
aptos move compile

# Run tests
aptos move test

# Publish to devnet
aptos move publish --named-addresses simple_coin=default
```

## 📖 Module Functions

### Admin Functions

#### `initialize(name, symbol, decimals, monitor_supply)`
Initialize the coin. Can only be called once by the module publisher.

```move
public entry fun initialize(
    account: &signer,
    name: vector<u8>,
    symbol: vector<u8>,
    decimals: u8,
    monitor_supply: bool,
)
```

#### `mint(recipient, amount)`
Mint new coins to a recipient address.

```move
public entry fun mint(
    owner: &signer,
    recipient: address,
    amount: u64,
)
```

### User Functions

#### `register()`
Register an account to receive SimpleCoin.

```move
public entry fun register(account: &signer)
```

#### `transfer(to, amount)`
Transfer coins to another address.

```move
public entry fun transfer(
    from: &signer,
    to: address,
    amount: u64,
)
```

#### `burn(amount)`
Burn coins from your account.

```move
public entry fun burn(
    account: &signer,
    amount: u64,
)
```

### View Functions (Gas-Free)

```move
#[view]
public fun balance_of(account: address): u64

#[view]
public fun name(): String

#[view]
public fun symbol(): String

#[view]
public fun decimals(): u8

#[view]
public fun total_supply(): u64
```

## 🔨 Usage Examples

### TypeScript/JavaScript Integration

```typescript
import { AptosClient, AptosAccount, FaucetClient } from "aptos";

const NODE_URL = "https://fullnode.devnet.aptoslabs.com";
const FAUCET_URL = "https://faucet.devnet.aptoslabs.com";

const client = new AptosClient(NODE_URL);
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);

// Create accounts
const owner = new AptosAccount();
const user = new AptosAccount();

// Fund accounts
await faucetClient.fundAccount(owner.address(), 100_000_000);
await faucetClient.fundAccount(user.address(), 100_000_000);

// Initialize coin
const initPayload = {
  type: "entry_function_payload",
  function: `${owner.address()}::coin::initialize`,
  type_arguments: [],
  arguments: [
    Buffer.from("SimpleCoin").toString("hex"),
    Buffer.from("SIMP").toString("hex"),
    "8",
    "true"
  ]
};

await client.generateSignSubmitTransaction(owner, initPayload);

// Mint tokens
const mintPayload = {
  type: "entry_function_payload",
  function: `${owner.address()}::coin::mint`,
  type_arguments: [],
  arguments: [user.address().hex(), "1000000"]
};

await client.generateSignSubmitTransaction(owner, mintPayload);

// Check balance
const balance = await client.view({
  function: `${owner.address()}::coin::balance_of`,
  type_arguments: [],
  arguments: [user.address().hex()]
});

console.log(`Balance: ${balance[0]}`);
```

### Python Integration

```python
from aptos_sdk.client import RestClient
from aptos_sdk.account import Account

NODE_URL = "https://fullnode.devnet.aptoslabs.com"
client = RestClient(NODE_URL)

# Create accounts
owner = Account.generate()
user = Account.generate()

# Fund accounts
client.fund_account(owner.address(), 100_000_000)
client.fund_account(user.address(), 100_000_000)

# Initialize coin
payload = {
    "type": "entry_function_payload",
    "function": f"{owner.address()}::coin::initialize",
    "type_arguments": [],
    "arguments": ["SimpleCoin", "SIMP", "8", True]
}

txn = await client.submit_transaction(owner, payload)
await client.wait_for_transaction(txn)

# Mint tokens
mint_payload = {
    "function": f"{owner.address()}::coin::mint",
    "arguments": [str(user.address()), "1000000"]
}

await client.submit_transaction(owner, mint_payload)
```

## 🧪 Testing

```bash
# Run all tests
aptos move test

# Run specific test
aptos move test --filter test_mint

# Run with coverage
aptos move test --coverage

# Verbose output
aptos move test --verbose
```

### Test Coverage

- ✅ Initialization
- ✅ Minting
- ✅ Transferring
- ✅ Burning
- ✅ Balance queries
- ✅ Metadata queries

## 🔐 Move Security Features

### Resource Safety

Move's resource model ensures:
1. **No Duplication**: Resources can't be copied
2. **No Loss**: Resources must be explicitly consumed
3. **Type Safety**: Strong compile-time guarantees
4. **Memory Safety**: No null pointers or dangling references

### Key Security Properties

```move
// ✅ This is safe - resources are linear types
struct Coin has store {
    value: u64
}

// ❌ This won't compile - can't copy resources
let coin1 = Coin { value: 100 };
let coin2 = coin1; // Error: can't copy
let coin3 = coin1; // Error: coin1 already moved
```

## 📊 Move vs Other Languages

| Feature | Move | Solidity | Rust |
|---------|------|----------|------|
| Resource Safety | ✅ Built-in | ❌ Manual | 🟡 Ownership |
| Formal Verification | ✅ Native | 🟡 External | 🟡 External |
| Reentrancy | ✅ Prevented | ❌ Possible | 🟡 Depends |
| Gas Model | Modern | Legacy | N/A |
| Learning Curve | Medium | Low | High |

## 📚 Resources

- [Move Book](https://move-language.github.io/move/)
- [Aptos Documentation](https://aptos.dev/)
- [Move Tutorial](https://github.com/move-language/move/tree/main/language/documentation/tutorial)
- [Aptos Move Examples](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples)

## 🎓 Key Move Concepts

### Resources

```move
// Resources are special types that can't be copied or dropped
struct Coin has key, store {
    value: u64
}

// Must be explicitly moved
public fun transfer(coin: Coin, to: address) {
    move_to<Coin>(to, coin);
}
```

### Generics

```move
// Type-safe generic programming
public fun swap<T>(x: T, y: T): (T, T) {
    (y, x)
}
```

### Abilities

```move
// copy: Can be copied
// drop: Can be dropped
// store: Can be stored in global storage
// key: Can be used as a key in global storage

struct MyCoin has key, store { value: u64 }
```

## 🌐 Deployment

### Devnet

```bash
aptos move publish \
  --named-addresses simple_coin=default \
  --assume-yes
```

### Mainnet

```bash
# Switch to mainnet profile
aptos init --profile mainnet --network mainnet

# Publish
aptos move publish \
  --profile mainnet \
  --named-addresses simple_coin=default \
  --assume-yes
```

## ⚠️ Why Move?

**Choose Move when:**
- Building on Aptos or Sui
- Security is paramount (DeFi, NFTs)
- You want formal verification
- You need strong safety guarantees

**Advantages:**
- No reentrancy bugs by design
- Resource safety prevents many exploits
- Clean, readable syntax
- Growing ecosystem

## 📄 License

MIT License

## 🔗 Additional Examples

- [Aptos Token Standard](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/framework/aptos-token)
- [NFT Example](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples/mint_nft)
- [DeFi Examples](https://github.com/pontem-network/move-language-examples)
