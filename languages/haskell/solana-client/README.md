# Haskell Solana Donation Client

A purely functional Solana donation contract client written in Haskell, demonstrating type-safe blockchain interactions with monadic error handling.

## Features

- **Type Safety**: Leverages Haskell's strong type system for compile-time guarantees
- **Monadic Operations**: Uses `Either` monad for error handling
- **Immutability**: All data structures are immutable by default
- **Pure Functions**: Side effects are isolated in IO monad

## Prerequisites

- GHC 9.4+ (Glasgow Haskell Compiler)
- Cabal or Stack
- `aeson` for JSON handling
- `http-client` for RPC calls

## Installation

```bash
cabal update
cabal install --lib aeson http-client base64-bytestring
```

## Code Structure

- `DonationClient.hs` - Main client implementation
- `Types.hs` - Type definitions and data structures
- `Crypto.hs` - Cryptographic operations

## Usage

```haskell
import DonationClient

main :: IO ()
main = do
  result <- runDonation $ do
    donor <- createKeypair
    tx <- donate donor (sol 0.1)
    pure tx
  case result of
    Left err -> putStrLn $ "Error: " <> show err
    Right tx -> putStrLn $ "Success: " <> show tx
```

## Benefits of Haskell

1. **Algebraic Data Types**: Sum and product types for precise modeling
2. **Lazy Evaluation**: Efficient handling of large data structures
3. **Type Classes**: Polymorphic interfaces for generic code
4. **Higher-Order Functions**: Composable, reusable abstractions
