# ☕ Java Web3j Integration

Enterprise-grade Ethereum integration using Web3j library for Java/Kotlin applications.

## ✨ Features

- **Wallet Management**: Create and manage Ethereum wallets
- **Transaction Handling**: Send and track transactions
- **Message Signing**: Sign and verify messages
- **Smart Contract**: Interact with smart contracts
- **Type Safety**: Strong typing with Java
- **Enterprise Ready**: Production-ready code

## 🛠️ Tech Stack

- **Java** 11+
- **Web3j** 4.10.0
- **Maven** 3.8+
- **JUnit** 5 for testing

## 📋 Prerequisites

```bash
java -version  # Should be 11+
mvn -version   # Should be 3.6+
```

## 🚀 Build & Run

```bash
cd languages/java/web3j-integration

# Build
mvn clean package

# Run
java -jar target/web3j-integration-1.0.0.jar

# Or run directly
mvn exec:java -Dexec.mainClass="com.web3.showcase.WalletManager"
```

## 🔨 Usage

### Basic Usage

```java
import com.web3.showcase.WalletManager;

WalletManager manager = new WalletManager();

// Create wallet
WalletInfo wallet = manager.createWallet();
System.out.println("Address: " + wallet.getAddress());

// Get balance
BigDecimal balance = manager.getBalance(wallet.getAddress());

// Send transaction
Credentials creds = Credentials.create(wallet.getKeyPair());
String txHash = manager.sendTransaction(
    creds,
    "0xRecipient",
    new BigDecimal("0.01")
);
```

## 📖 API Reference

### WalletManager Methods

#### `createWallet() -> WalletInfo`
Create new Ethereum wallet.

#### `loadWallet(String privateKey) -> Credentials`
Load wallet from private key.

#### `getBalance(String address) -> BigDecimal`
Get ETH balance for address.

#### `sendTransaction(Credentials, String to, BigDecimal amount) -> String`
Send ETH transaction.

#### `signMessage(String message, Credentials) -> String`
Sign message with private key.

#### `getGasPrice() -> BigInteger`
Get current gas price.

## 🧪 Testing

```bash
# Run tests
mvn test

# Run with coverage
mvn test jacoco:report

# View coverage
open target/site/jacoco/index.html
```

## 📄 License

MIT License

## 📚 Resources

- [Web3j Documentation](https://docs.web3j.io/)
- [Ethereum for Java Developers](https://ethereum.org/en/developers/docs/programming-languages/java/)
