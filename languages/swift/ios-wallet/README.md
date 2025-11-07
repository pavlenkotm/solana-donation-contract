# 📱 Swift iOS Wallet SDK

Professional Ethereum wallet SDK for iOS applications built with Swift and SwiftUI.

## ✨ Features

- **Wallet Creation**: Generate new HD wallets with BIP39 mnemonics
- **Wallet Import**: Import from mnemonic phrase
- **Balance Queries**: Check ETH balances
- **Transactions**: Send ETH transactions
- **Message Signing**: Sign and verify messages
- **SwiftUI Integration**: Ready-to-use UI components
- **Type Safety**: Full Swift type safety
- **iOS 13+**: Modern iOS development

## 🛠️ Tech Stack

- **Swift** 5.9+
- **web3swift** - Ethereum Swift library
- **SwiftUI** - Modern UI framework
- **CryptoKit** - Apple's cryptography framework
- **Swift Package Manager**

## 📋 Prerequisites

- Xcode 14+
- iOS 13+
- Swift 5.9+

## 🚀 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/web3swift-team/web3swift.git", from: "3.1.0")
]
```

### Manual

```bash
cd languages/swift/ios-wallet

# Build
swift build

# Run tests
swift test
```

## 🔨 Usage

### Basic Usage

```swift
import EthereumWalletSDK

let sdk = EthereumWalletSDK()

// Create wallet
let wallet = try sdk.createWallet()
print("Address: \(wallet.address)")
print("Mnemonic: \(wallet.mnemonic)")

// Get balance
let balance = try await sdk.getBalance(address: wallet.address)
print("Balance: \(balance) ETH")

// Send transaction
let txHash = try await sdk.sendTransaction(
    from: wallet.address,
    to: "0xRecipient",
    amount: "0.01",
    keystore: wallet.keystore
)
```

### SwiftUI Integration

```swift
import SwiftUI
import EthereumWalletSDK

struct ContentView: View {
    var body: some View {
        WalletView()
    }
}
```

## 📚 API Documentation

### EthereumWalletSDK

#### `createWallet() throws -> WalletInfo`
Create new Ethereum wallet with BIP39 mnemonic.

#### `importWallet(mnemonic: String) throws -> WalletInfo`
Import wallet from mnemonic phrase.

#### `getBalance(address: String) async throws -> String`
Get ETH balance for address.

#### `sendTransaction(...) async throws -> String`
Send ETH transaction.

#### `signMessage(message: String, keystore:) throws -> String`
Sign message with private key.

## 🧪 Testing

```bash
# Run tests
swift test

# Run with coverage
swift test --enable-code-coverage
```

## 📱 Example App

See `WalletView.swift` for complete SwiftUI example.

## 📄 License

MIT License

## 🔗 Resources

- [web3swift Documentation](https://github.com/web3swift-team/web3swift)
- [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
