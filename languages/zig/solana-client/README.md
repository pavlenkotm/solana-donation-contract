# Zig Solana Donation Client

A blazingly fast, memory-safe Solana donation contract client written in Zig, offering manual memory management with compile-time safety guarantees.

## Features

- **Performance**: Zero-cost abstractions and manual memory control
- **Safety**: Compile-time memory safety checks
- **Simplicity**: No hidden control flow or allocations
- **Cross-compilation**: Easy cross-compilation to any target
- **Comptime**: Powerful compile-time execution

## Prerequisites

- Zig 0.11+
- Dependencies: `std.http`, `std.json`, `std.crypto`

## Installation

```bash
zig build
zig build run
```

## Project Structure

```
src/
  ├── main.zig               # Main entry point
  ├── donation_client.zig    # Client implementation
  ├── types.zig              # Type definitions
  └── crypto.zig             # Cryptographic utilities
```

## Usage

```zig
const std = @import("std");
const DonationClient = @import("donation_client.zig").DonationClient;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create client
    var client = try DonationClient.init(allocator, .{
        .rpc_url = "https://api.devnet.solana.com",
    });
    defer client.deinit();

    // Make donation
    const donor = "DonorPubkey123...";
    const result = try client.donate(donor, 0.5);
    std.debug.print("Signature: {s}\n", .{result.signature});

    // Get vault stats
    const stats = try client.getVaultStats();
    std.debug.print("Total donated: {d} SOL\n", .{stats.totalDonated.toSol()});
}
```

## Benefits of Zig

1. **Explicit**: No hidden memory allocations or control flow
2. **Fast**: Performance comparable to C
3. **Safe**: Compile-time safety with runtime checks where needed
4. **Simple**: Small, focused language without complexity
5. **Interop**: First-class C ABI compatibility
