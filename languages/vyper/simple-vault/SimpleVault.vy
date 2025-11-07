# @version ^0.3.10
"""
@title Simple Vault
@author Web3 Multi-Language Showcase
@notice A simple vault contract for storing ETH with access control
@dev Demonstrates Vyper syntax and security features
"""

# Events
event Deposited:
    depositor: indexed(address)
    amount: uint256
    newBalance: uint256

event Withdrawn:
    recipient: indexed(address)
    amount: uint256
    remainingBalance: uint256

event OwnershipTransferred:
    previousOwner: indexed(address)
    newOwner: indexed(address)

# State variables
owner: public(address)
totalDeposits: public(uint256)
withdrawalCount: public(uint256)
isPaused: public(bool)

# Mapping to track individual balances
balances: public(HashMap[address, uint256])

@external
def __init__():
    """
    @notice Contract constructor
    @dev Sets the contract deployer as the owner
    """
    self.owner = msg.sender
    self.isPaused = False
    self.totalDeposits = 0
    self.withdrawalCount = 0

@external
@payable
def deposit():
    """
    @notice Deposit ETH into the vault
    @dev Requires contract not to be paused and minimum deposit amount
    """
    assert not self.isPaused, "Vault is paused"
    assert msg.value > 0, "Deposit must be greater than 0"

    self.balances[msg.sender] += msg.value
    self.totalDeposits += msg.value

    log Deposited(msg.sender, msg.value, self.balances[msg.sender])

@external
def withdraw(amount: uint256):
    """
    @notice Withdraw ETH from your balance
    @param amount Amount of ETH to withdraw in wei
    @dev Requires sufficient balance and non-paused state
    """
    assert not self.isPaused, "Vault is paused"
    assert amount > 0, "Withdraw amount must be > 0"
    assert self.balances[msg.sender] >= amount, "Insufficient balance"

    self.balances[msg.sender] -= amount
    self.withdrawalCount += 1

    # Send ETH using raw_call for security
    send(msg.sender, amount)

    log Withdrawn(msg.sender, amount, self.balances[msg.sender])

@external
def withdrawAll():
    """
    @notice Withdraw all your balance
    @dev Convenience function for full withdrawal
    """
    balance: uint256 = self.balances[msg.sender]
    assert balance > 0, "No balance to withdraw"

    self.withdraw(balance)

@external
def emergencyWithdraw():
    """
    @notice Emergency withdrawal by owner (even when paused)
    @dev Only owner can call this function
    """
    assert msg.sender == self.owner, "Only owner"

    # Get contract balance
    contractBalance: uint256 = self.balance
    assert contractBalance > 0, "No funds to withdraw"

    # Transfer all funds to owner
    send(self.owner, contractBalance)

@external
def pause():
    """
    @notice Pause the vault (owner only)
    @dev Prevents deposits and withdrawals
    """
    assert msg.sender == self.owner, "Only owner"
    assert not self.isPaused, "Already paused"

    self.isPaused = True

@external
def unpause():
    """
    @notice Unpause the vault (owner only)
    @dev Resumes normal operations
    """
    assert msg.sender == self.owner, "Only owner"
    assert self.isPaused, "Not paused"

    self.isPaused = False

@external
def transferOwnership(newOwner: address):
    """
    @notice Transfer ownership to a new address
    @param newOwner Address of the new owner
    @dev Only current owner can call this
    """
    assert msg.sender == self.owner, "Only owner"
    assert newOwner != empty(address), "Invalid address"

    oldOwner: address = self.owner
    self.owner = newOwner

    log OwnershipTransferred(oldOwner, newOwner)

@view
@external
def getBalance(account: address) -> uint256:
    """
    @notice Get balance of a specific account
    @param account Address to check
    @return Balance in wei
    """
    return self.balances[account]

@view
@external
def getContractBalance() -> uint256:
    """
    @notice Get total ETH held by the contract
    @return Total balance in wei
    """
    return self.balance

@view
@external
def getStats() -> (uint256, uint256, uint256, bool):
    """
    @notice Get vault statistics
    @return Tuple of (totalDeposits, withdrawalCount, contractBalance, isPaused)
    """
    return (self.totalDeposits, self.withdrawalCount, self.balance, self.isPaused)
