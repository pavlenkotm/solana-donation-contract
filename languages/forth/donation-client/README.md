# Forth Solana Donation Client

A minimalist, stack-based Solana donation contract client written in Forth, demonstrating the elegance of concatenative programming.

## Features

- **Stack-Based**: Reverse Polish Notation (RPN) for operations
- **Minimal**: Extremely small footprint
- **Extensible**: Define new words easily
- **Interactive**: REPL-driven development
- **Efficient**: Direct hardware access

## Prerequisites

- GForth 0.7+ or SwiftForth
- Basic understanding of stack-based programming
- Forth RPC library (custom implementation included)

## Installation

```bash
gforth donation-client.fs
```

## Stack Notation

Forth uses stack notation to describe operations:
- `( n1 n2 -- n3 )` means: takes two numbers, returns one
- Items to the left of `--` are inputs (top of stack on right)
- Items to the right of `--` are outputs

## Usage

```forth
\ Initialize client
init-client

\ Make donation (0.5 SOL)
s" DonorPubkey123..." 500000000 donate
.s  \ Display stack (signature)

\ Get vault statistics
get-vault-stats
.stats

\ Get donor info
s" DonorPubkey123..." get-donor-info
.donor-info

\ Calculate tier from lamports
500000000 calculate-tier
tier-emoji type cr
```

## Example Session

```forth
Gforth 0.7.3, Copyright (C) 1995-2008 Free Software Foundation, Inc.
Gforth comes with ABSOLUTELY NO WARRANTY; for details type `license'
Type `bye' to exit

include donation-client.fs  ok
init-client  ok
s" Donor123" 1000000000 donate  ok
cr ." Donation signature: " type cr  ok
Donation signature: sig_abc123
get-vault-stats  ok
." Total donated: " total-donated @ u. ." lamports" cr  ok
Total donated: 5000000000 lamports
```

## Benefits of Forth

1. **Simplicity**: Minimal syntax, easy to learn core
2. **Efficiency**: Direct control over execution
3. **Interactive**: Immediate feedback during development
4. **Compact**: Tiny executables
5. **Extensible**: Build domain-specific languages easily
