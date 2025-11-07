# 🐍 Python Web3 Scripts

Professional Python scripts for Ethereum blockchain interaction using Web3.py library.

## ✨ Features

- **Wallet Management**: Create and manage Ethereum wallets
- **Balance Queries**: Check ETH balances
- **Transaction Sending**: Send ETH transactions
- **Gas Estimation**: Estimate transaction costs
- **Message Signing**: Sign and verify messages
- **Type Safety**: Full type hints throughout
- **Error Handling**: Comprehensive error handling

## 🛠️ Tech Stack

- **Python** 3.8+
- **Web3.py** 6.11.0+
- **eth-account** for wallet management
- **Type hints** for better code quality

## 📋 Prerequisites

```bash
python3 --version  # Should be 3.8+
pip3 --version
```

## 🚀 Installation

```bash
cd languages/python/web3-scripts

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## 🔨 Usage

### Basic Usage

```bash
# Run wallet manager
python wallet_manager.py
```

### Programmatic Usage

```python
from wallet_manager import WalletManager

# Initialize
manager = WalletManager("https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY")

# Create account
account = manager.create_account()
print(f"Address: {account['address']}")

# Check balance
balance = manager.get_balance("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
print(f"Balance: {balance} ETH")

# Send transaction
tx_hash = manager.send_transaction(
    from_private_key="0x...",
    to_address="0x...",
    amount_eth=0.01
)

# Wait for confirmation
receipt = manager.wait_for_transaction(tx_hash)
print(f"Status: {receipt['status']}")
```

## 📖 API Reference

### WalletManager Class

#### `__init__(provider_url: str)`
Initialize wallet manager with Ethereum node URL.

#### `create_account() -> Dict[str, str]`
Create new Ethereum account.

**Returns:**
```python
{
    "address": "0x...",
    "private_key": "0x..."
}
```

#### `get_balance(address: str) -> Decimal`
Get ETH balance for address.

#### `send_transaction(from_private_key, to_address, amount_eth, gas_price=None) -> str`
Send ETH transaction.

**Returns:** Transaction hash

#### `wait_for_transaction(tx_hash: str, timeout: int = 120) -> Dict`
Wait for transaction confirmation.

#### `get_transaction(tx_hash: str) -> Dict`
Get transaction details.

#### `estimate_gas(from_address, to_address, amount_eth) -> int`
Estimate gas for transaction.

#### `get_gas_price() -> Dict[str, int]`
Get current gas prices in wei and gwei.

#### `sign_message(message: str, private_key: str) -> str`
Sign message with private key.

#### `verify_signature(message, signature, expected_address) -> bool`
Verify message signature.

## 🧪 Testing

```bash
# Install testing dependencies
pip install pytest pytest-cov

# Run tests
pytest

# Run with coverage
pytest --cov=wallet_manager --cov-report=html
```

## 📝 Examples

### Example 1: Multi-Send Script

```python
from wallet_manager import WalletManager

manager = WalletManager()

recipients = [
    ("0xRecipient1", 0.01),
    ("0xRecipient2", 0.02),
    ("0xRecipient3", 0.03),
]

private_key = "0xYourPrivateKey"

for address, amount in recipients:
    tx_hash = manager.send_transaction(
        from_private_key=private_key,
        to_address=address,
        amount_eth=amount
    )
    print(f"Sent {amount} ETH to {address}: {tx_hash}")
```

### Example 2: Balance Monitor

```python
import time
from wallet_manager import WalletManager

manager = WalletManager()
address = "0xYourAddress"

print(f"Monitoring balance for {address}")

last_balance = manager.get_balance(address)

while True:
    current_balance = manager.get_balance(address)

    if current_balance != last_balance:
        change = current_balance - last_balance
        print(f"Balance changed: {change:+.4f} ETH")
        print(f"New balance: {current_balance} ETH")
        last_balance = current_balance

    time.sleep(10)  # Check every 10 seconds
```

### Example 3: Smart Contract Interaction

```python
from web3 import Web3
from wallet_manager import WalletManager

manager = WalletManager()

# Contract ABI and address
contract_abi = [...]  # Your contract ABI
contract_address = "0xContractAddress"

# Create contract instance
contract = manager.w3.eth.contract(
    address=Web3.to_checksum_address(contract_address),
    abi=contract_abi
)

# Call view function
result = contract.functions.balanceOf("0xAddress").call()
print(f"Token balance: {result}")

# Send transaction
account = Account.from_key("0xPrivateKey")
tx = contract.functions.transfer(
    "0xRecipient",
    1000
).build_transaction({
    'from': account.address,
    'nonce': manager.w3.eth.get_transaction_count(account.address),
    'gas': 100000,
    'gasPrice': manager.w3.eth.gas_price,
})

signed_tx = account.sign_transaction(tx)
tx_hash = manager.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
print(f"Transaction sent: {tx_hash.hex()}")
```

## 🔐 Security Best Practices

1. **Never hardcode private keys**
   ```python
   # ❌ Bad
   private_key = "0x1234..."

   # ✅ Good
   import os
   private_key = os.environ.get("PRIVATE_KEY")
   ```

2. **Use environment variables**
   ```bash
   # .env file
   PRIVATE_KEY=0x...
   INFURA_KEY=...
   ```

   ```python
   from dotenv import load_dotenv
   load_dotenv()
   ```

3. **Validate addresses**
   ```python
   from eth_utils import is_address

   if not is_address(address):
       raise ValueError("Invalid address")
   ```

4. **Use checksum addresses**
   ```python
   checksum_addr = Web3.to_checksum_address(address)
   ```

## 📚 Resources

- [Web3.py Documentation](https://web3py.readthedocs.io/)
- [Ethereum Python](https://ethereum.org/en/developers/docs/programming-languages/python/)
- [eth-account Docs](https://eth-account.readthedocs.io/)

## 🌐 Supported Networks

- **Mainnet**: `https://mainnet.infura.io/v3/YOUR_KEY`
- **Sepolia**: `https://sepolia.infura.io/v3/YOUR_KEY`
- **Goerli**: `https://goerli.infura.io/v3/YOUR_KEY`
- **Local**: `http://127.0.0.1:8545`
- **Polygon**: `https://polygon-rpc.com`
- **Arbitrum**: `https://arb1.arbitrum.io/rpc`
- **Optimism**: `https://mainnet.optimism.io`

## ⚡ Performance Tips

1. **Use batch requests** for multiple calls
2. **Cache provider** connections
3. **Use async** for concurrent operations
4. **Implement retry logic** for network errors

## 📄 License

MIT License

## 🎓 Learn More

- [Python Ethereum Ecosystem](https://github.com/ethereum/ethereum-org-website/blob/dev/public/content/developers/docs/programming-languages/python/index.md)
- [Web3.py Examples](https://github.com/ethereum/web3.py/tree/master/examples)
- [Brownie Framework](https://eth-brownie.readthedocs.io/)
