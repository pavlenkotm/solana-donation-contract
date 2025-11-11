# Nim Solana Donation Client

An efficient, systems-level Solana donation contract client written in Nim, combining Python-like syntax with C-like performance.

## Features

- **Performance**: Compiles to C for native performance
- **Expressiveness**: Python-like syntax with static typing
- **Memory Safety**: Garbage collection with manual override options
- **Metaprogramming**: Powerful macro system
- **Cross-platform**: Compiles to C, C++, JavaScript, or Objective-C

## Prerequisites

- Nim 2.0+
- Nimble (package manager)
- Dependencies: `jsony`, `httpClient`, `crypto`

## Installation

```bash
nimble install jsony
nim c -r donation_client.nim
```

## Project Structure

```
src/
  ├── donation_client.nim    # Main client module
  ├── types.nim              # Type definitions
  ├── crypto.nim             # Cryptographic utilities
  └── rpc.nim                # RPC client
```

## Usage

```nim
import donation_client

# Create client
let client = newDonationClient("https://api.devnet.solana.com")

# Make donation
let result = client.donate(donorPubkey, 0.5.SOL)
echo "Donation signature: ", result.signature

# Get vault statistics
let stats = client.getVaultStats()
echo "Total donated: ", stats.totalDonated.toSOL(), " SOL"

# Pattern matching on tier
case client.getDonorInfo(donorPubkey).tier
of Platinum: echo "You're a platinum donor! 💎"
of Gold: echo "You're a gold donor! 🥇"
of Silver: echo "You're a silver donor! 🥈"
of Bronze: echo "You're a bronze donor! 🥉"
```

## Benefits of Nim

1. **Efficiency**: Compiles to optimized C code
2. **Readability**: Clean, Python-like syntax
3. **Type Safety**: Strong static typing with inference
4. **Metaprogramming**: Templates and macros for code generation
5. **Interoperability**: Easy FFI with C/C++
