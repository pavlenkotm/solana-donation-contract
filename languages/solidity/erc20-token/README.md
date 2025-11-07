# 🪙 Solidity ERC-20 Token

A professional, production-ready ERC-20 token implementation using OpenZeppelin contracts and Hardhat development environment.

## ✨ Features

- **Standard ERC-20**: Full compliance with ERC-20 token standard
- **Mintable**: Owner can mint new tokens (with max supply cap)
- **Burnable**: Token holders can burn their tokens
- **Access Control**: Owner-only administrative functions
- **Batch Transfers**: Send tokens to multiple addresses in one transaction
- **Max Supply Cap**: Configurable maximum supply limit
- **Event Emission**: Comprehensive events for tracking
- **Gas Optimized**: Optimized for minimal gas consumption

## 🛠️ Tech Stack

- **Solidity** 0.8.20
- **OpenZeppelin Contracts** 5.0.0
- **Hardhat** - Development environment
- **Ethers.js** - Ethereum library
- **Chai** - Testing framework

## 📋 Prerequisites

- Node.js 18+
- npm or yarn

## 🚀 Installation

```bash
cd languages/solidity/erc20-token
npm install
```

## 🔨 Usage

### Compile Contract

```bash
npm run compile
```

### Run Tests

```bash
npm test
```

### Deploy Locally

```bash
# Start local Hardhat node in one terminal
npx hardhat node

# Deploy in another terminal
npm run deploy:local
```

### Deploy to Sepolia Testnet

```bash
# Set environment variables
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_KEY"
export PRIVATE_KEY="your_private_key"

# Deploy
npm run deploy:sepolia
```

## 📖 Contract API

### Constructor

```solidity
constructor(
    string memory name,        // Token name (e.g., "My Token")
    string memory symbol,      // Token symbol (e.g., "MTK")
    uint256 initialSupply,     // Initial supply in wei
    uint8 tokenDecimals,       // Number of decimals (usually 18)
    uint256 _maxSupply         // Max supply cap (0 for unlimited)
)
```

### Key Functions

#### `mint(address to, uint256 amount)`
Mints new tokens to specified address (owner only).

#### `burn(uint256 amount)`
Burns tokens from caller's balance.

#### `batchTransfer(address[] recipients, uint256[] amounts)`
Transfers tokens to multiple recipients in one transaction.

#### `updateMaxSupply(uint256 newMaxSupply)`
Updates the maximum supply cap (owner only).

### Events

- `TokensMinted(address indexed to, uint256 amount)`
- `MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply)`
- Standard ERC-20 events: `Transfer`, `Approval`

## 🧪 Test Coverage

The project includes comprehensive tests covering:
- ✅ Deployment and initialization
- ✅ Minting functionality
- ✅ Burning mechanism
- ✅ Batch transfers
- ✅ Max supply constraints
- ✅ Access control
- ✅ Edge cases and error conditions

## 🔐 Security Features

1. **OpenZeppelin Contracts**: Battle-tested, audited contract library
2. **Access Control**: Owner-only functions for sensitive operations
3. **Input Validation**: Comprehensive checks on all inputs
4. **Safe Math**: Built-in overflow protection (Solidity 0.8+)
5. **Max Supply Cap**: Prevents unlimited inflation
6. **Reentrancy Protection**: Safe transfer patterns

## 📝 Example Usage

```javascript
const { ethers } = require("ethers");

// Deploy token
const SimpleToken = await ethers.getContractFactory("SimpleToken");
const token = await SimpleToken.deploy(
  "MyToken",
  "MTK",
  ethers.parseEther("1000000"),  // 1M initial supply
  18,                             // 18 decimals
  ethers.parseEther("10000000")  // 10M max supply
);

// Mint new tokens
await token.mint(recipientAddress, ethers.parseEther("1000"));

// Batch transfer
await token.batchTransfer(
  [addr1, addr2, addr3],
  [ethers.parseEther("100"), ethers.parseEther("200"), ethers.parseEther("300")]
);

// Burn tokens
await token.burn(ethers.parseEther("50"));
```

## 📚 Resources

- [OpenZeppelin ERC-20 Documentation](https://docs.openzeppelin.com/contracts/erc20)
- [Hardhat Documentation](https://hardhat.org/docs)
- [ERC-20 Token Standard](https://eips.ethereum.org/EIPS/eip-20)

## ⚠️ Disclaimer

This code is provided for educational purposes. Audit thoroughly before using in production.

## 📄 License

MIT License - see LICENSE file for details
