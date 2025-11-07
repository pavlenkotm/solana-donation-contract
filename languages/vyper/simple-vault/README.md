# 🐍 Vyper Simple Vault

A secure vault contract written in Vyper - Python-like smart contract language for Ethereum.

## 🎯 Overview

Vyper is an alternative to Solidity designed with security and simplicity in mind. This vault contract demonstrates Vyper's syntax, security features, and best practices.

## ✨ Features

- **Secure Deposits**: Store ETH safely in the vault
- **Individual Balances**: Track each user's balance
- **Pausable**: Emergency pause mechanism
- **Withdrawal Controls**: Withdraw specific amounts or all balance
- **Owner Controls**: Administrative functions for vault management
- **Emergency Withdrawal**: Owner can withdraw all funds in emergencies
- **Event Logging**: Comprehensive event emission

## 🛠️ Tech Stack

- **Vyper** ^0.3.10
- **Python** 3.8+
- **Ape Framework** (recommended)
- **Brownie** or **Titanoboa** for testing

## 📋 Prerequisites

```bash
# Install Python 3.8+
sudo apt install python3 python3-pip

# Install Vyper
pip install vyper

# Verify installation
vyper --version
```

## 🚀 Installation

```bash
cd languages/vyper/simple-vault

# Install Ape framework (recommended)
pip install eth-ape
pip install ape-vyper

# Or install Brownie
pip install eth-brownie
```

## 🔨 Usage

### Compile Contract

```bash
# Using Vyper directly
vyper SimpleVault.vy

# Using Ape
ape compile

# Get ABI
vyper -f abi SimpleVault.vy > SimpleVault.abi
```

### Deploy

```python
# Example using Ape
from ape import accounts, project

def main():
    # Get deployer account
    deployer = accounts.load("my-account")

    # Deploy vault
    vault = deployer.deploy(project.SimpleVault)

    print(f"Vault deployed at: {vault.address}")
    print(f"Owner: {vault.owner()}")
```

### Interact with Contract

```python
# Deposit ETH
vault.deposit(value="1 ether", sender=user)

# Check balance
balance = vault.getBalance(user.address)

# Withdraw specific amount
vault.withdraw(500000000000000000, sender=user)  # 0.5 ETH

# Withdraw all
vault.withdrawAll(sender=user)

# Owner: Pause vault
vault.pause(sender=owner)

# Owner: Emergency withdraw
vault.emergencyWithdraw(sender=owner)
```

## 📖 Contract Functions

### User Functions

#### `deposit() payable`
Deposit ETH into the vault. Tracks individual balances.

#### `withdraw(amount: uint256)`
Withdraw specific amount from your balance.

#### `withdrawAll()`
Withdraw your entire balance.

#### `getBalance(account: address) -> uint256`
Get balance of a specific account.

### Owner Functions

#### `pause()`
Pause the vault (prevents deposits and withdrawals).

#### `unpause()`
Resume normal operations.

#### `emergencyWithdraw()`
Withdraw all funds (works even when paused).

#### `transferOwnership(newOwner: address)`
Transfer ownership to a new address.

### View Functions

#### `getContractBalance() -> uint256`
Get total ETH held by contract.

#### `getStats() -> (uint256, uint256, uint256, bool)`
Get comprehensive vault statistics.

## 🔐 Security Features

### Vyper Security Advantages

1. **No Modifiers**: Reduces complexity and hidden bugs
2. **No Recursive Calls**: Prevents reentrancy by design
3. **Bounds Checking**: Automatic overflow protection
4. **Clear Visibility**: All functions explicitly declared
5. **No Dynamic Arrays**: Prevents gas issues
6. **Simpler Syntax**: Easier to audit and understand

### Contract-Specific Security

- Owner-only administrative functions
- Pause mechanism for emergencies
- Input validation on all functions
- Safe ETH transfers using `send()`
- Balance tracking prevents over-withdrawal

## 🧪 Testing Example

```python
import pytest
from ape import accounts, project

@pytest.fixture
def vault(accounts):
    return accounts[0].deploy(project.SimpleVault)

def test_deposit(vault, accounts):
    user = accounts[1]
    deposit_amount = "1 ether"

    # Deposit
    vault.deposit(value=deposit_amount, sender=user)

    # Check balance
    assert vault.getBalance(user) == deposit_amount

def test_withdraw(vault, accounts):
    user = accounts[1]

    # Deposit first
    vault.deposit(value="1 ether", sender=user)

    # Withdraw half
    withdraw_amount = 500000000000000000  # 0.5 ETH
    vault.withdraw(withdraw_amount, sender=user)

    # Check remaining balance
    assert vault.getBalance(user) == withdraw_amount

def test_pause(vault, accounts):
    owner = accounts[0]
    user = accounts[1]

    # Pause vault
    vault.pause(sender=owner)

    # Try to deposit (should fail)
    with pytest.raises(Exception):
        vault.deposit(value="1 ether", sender=user)
```

## 📊 Why Vyper?

| Feature | Vyper | Solidity |
|---------|-------|----------|
| Syntax | Python-like | JavaScript-like |
| Security Focus | High | Medium |
| Complexity | Lower | Higher |
| Recursion | Not allowed | Allowed |
| Inheritance | Limited | Full OOP |
| Best For | Financial contracts | Complex dApps |

## 📚 Resources

- [Vyper Documentation](https://docs.vyperlang.org/)
- [Vyper by Example](https://vyper.readthedocs.io/en/stable/vyper-by-example.html)
- [Ape Framework Docs](https://docs.apeworx.io/)
- [Vyper Security Guide](https://docs.vyperlang.org/en/stable/security-considerations.html)

## ⚠️ Vyper vs Solidity

**Choose Vyper when:**
- Building financial contracts (DeFi protocols)
- Security is the top priority
- You prefer Python-like syntax
- You want simpler, more auditable code

**Choose Solidity when:**
- Need complex inheritance
- Require maximum flexibility
- Building complex dApps with many features
- Need extensive library support

## 📄 License

MIT License

## 🎓 Learning Resources

- [Curve Finance](https://github.com/curvefi/curve-contract) - Major DeFi protocol built with Vyper
- [Yearn Vaults](https://github.com/yearn/yearn-vaults) - Production Vyper contracts
- [Vyper Cookbook](https://github.com/vyperlang/vyper/tree/master/examples)
