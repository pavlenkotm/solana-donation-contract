# Crystal Solana Donation Client

A fast, type-safe Solana donation contract client written in Crystal, combining Ruby-like syntax with native performance.

## Features

- **Performance**: Compiles to native code via LLVM
- **Type Safety**: Statically typed with type inference
- **Syntax**: Ruby-inspired elegant syntax
- **Concurrency**: Lightweight fibers for concurrent operations
- **Null Safety**: Compile-time null checking

## Prerequisites

- Crystal 1.10+
- Shards (package manager)
- Dependencies: `http`, `json`, `base64`

## Installation

```bash
shards install
crystal build src/donation_client.cr --release
```

## Project Structure

```
src/
  ├── donation_client.cr     # Main client module
  ├── types.cr               # Type definitions
  ├── errors.cr              # Custom exceptions
  └── rpc/
      └── client.cr          # RPC client
```

## Usage

```crystal
require "./donation_client"

# Create client
client = DonationClient.new

# Make donation
result = client.donate(donor_pubkey, amount: 0.5)
puts "Signature: #{result.signature}"
puts "New tier: #{result.new_tier.emoji}"

# Get vault statistics
stats = client.vault_stats
puts "Total donated: #{stats.total_donated.to_sol} SOL"

# Pattern matching on tier
case client.donor_info(donor_pubkey).tier
when .platinum?
  puts "You're a platinum donor! 💎"
when .gold?
  puts "You're a gold donor! 🥇"
else
  puts "Keep donating to reach higher tiers!"
end
```

## Benefits of Crystal

1. **Speed**: Compiled to native code, as fast as C
2. **Elegance**: Ruby-like syntax for readable code
3. **Safety**: Compile-time type checking
4. **Productivity**: Powerful type inference reduces boilerplate
5. **Concurrency**: Built-in support for concurrent programming
