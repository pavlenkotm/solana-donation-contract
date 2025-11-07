#!/usr/bin/env python3
"""
Ethereum Wallet Manager - Web3.py Integration Example
Demonstrates wallet creation, balance checking, and transaction sending
"""

from web3 import Web3
from eth_account import Account
from eth_typing import Address
import json
import os
from typing import Optional, Dict, Any
from decimal import Decimal


class WalletManager:
    """Ethereum wallet manager using Web3.py"""

    def __init__(self, provider_url: str = "https://eth-sepolia.g.alchemy.com/v2/demo"):
        """
        Initialize wallet manager with Web3 provider

        Args:
            provider_url: Ethereum node RPC URL
        """
        self.w3 = Web3(Web3.HTTPProvider(provider_url))

        if not self.w3.is_connected():
            raise ConnectionError(f"Failed to connect to {provider_url}")

        print(f"✅ Connected to Ethereum network")
        print(f"Chain ID: {self.w3.eth.chain_id}")

    def create_account(self) -> Dict[str, str]:
        """
        Create a new Ethereum account

        Returns:
            Dictionary with address and private key
        """
        account = Account.create()

        return {
            "address": account.address,
            "private_key": account.key.hex(),
        }

    def get_balance(self, address: str) -> Decimal:
        """
        Get ETH balance for an address

        Args:
            address: Ethereum address

        Returns:
            Balance in ETH
        """
        checksum_address = Web3.to_checksum_address(address)
        balance_wei = self.w3.eth.get_balance(checksum_address)
        balance_eth = Web3.from_wei(balance_wei, 'ether')

        return Decimal(str(balance_eth))

    def send_transaction(
        self,
        from_private_key: str,
        to_address: str,
        amount_eth: float,
        gas_price: Optional[int] = None
    ) -> str:
        """
        Send ETH transaction

        Args:
            from_private_key: Sender's private key
            to_address: Recipient address
            amount_eth: Amount in ETH
            gas_price: Gas price in wei (optional, uses network default)

        Returns:
            Transaction hash
        """
        # Get account from private key
        account = Account.from_key(from_private_key)

        # Convert addresses to checksum format
        to_checksum = Web3.to_checksum_address(to_address)

        # Build transaction
        transaction = {
            'from': account.address,
            'to': to_checksum,
            'value': Web3.to_wei(amount_eth, 'ether'),
            'nonce': self.w3.eth.get_transaction_count(account.address),
            'gas': 21000,
            'chainId': self.w3.eth.chain_id,
        }

        # Set gas price
        if gas_price:
            transaction['gasPrice'] = gas_price
        else:
            transaction['gasPrice'] = self.w3.eth.gas_price

        # Sign transaction
        signed_txn = self.w3.eth.account.sign_transaction(
            transaction, from_private_key
        )

        # Send transaction
        tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)

        print(f"✅ Transaction sent: {tx_hash.hex()}")

        return tx_hash.hex()

    def wait_for_transaction(self, tx_hash: str, timeout: int = 120) -> Dict[str, Any]:
        """
        Wait for transaction to be mined

        Args:
            tx_hash: Transaction hash
            timeout: Timeout in seconds

        Returns:
            Transaction receipt
        """
        print(f"⏳ Waiting for transaction {tx_hash}...")

        receipt = self.w3.eth.wait_for_transaction_receipt(
            tx_hash, timeout=timeout
        )

        if receipt['status'] == 1:
            print(f"✅ Transaction successful!")
        else:
            print(f"❌ Transaction failed!")

        return dict(receipt)

    def get_transaction(self, tx_hash: str) -> Dict[str, Any]:
        """
        Get transaction details

        Args:
            tx_hash: Transaction hash

        Returns:
            Transaction details
        """
        tx = self.w3.eth.get_transaction(tx_hash)
        return dict(tx)

    def estimate_gas(
        self,
        from_address: str,
        to_address: str,
        amount_eth: float
    ) -> int:
        """
        Estimate gas for a transaction

        Args:
            from_address: Sender address
            to_address: Recipient address
            amount_eth: Amount in ETH

        Returns:
            Estimated gas
        """
        gas_estimate = self.w3.eth.estimate_gas({
            'from': Web3.to_checksum_address(from_address),
            'to': Web3.to_checksum_address(to_address),
            'value': Web3.to_wei(amount_eth, 'ether'),
        })

        return gas_estimate

    def get_gas_price(self) -> Dict[str, int]:
        """
        Get current gas prices

        Returns:
            Dictionary with gas prices in Gwei
        """
        gas_price_wei = self.w3.eth.gas_price
        gas_price_gwei = Web3.from_wei(gas_price_wei, 'gwei')

        return {
            'wei': gas_price_wei,
            'gwei': int(gas_price_gwei),
        }

    def sign_message(self, message: str, private_key: str) -> str:
        """
        Sign a message with private key

        Args:
            message: Message to sign
            private_key: Private key

        Returns:
            Signature
        """
        account = Account.from_key(private_key)
        message_hash = self.w3.keccak(text=message)
        signed_message = account.signHash(message_hash)

        return signed_message.signature.hex()

    def verify_signature(
        self,
        message: str,
        signature: str,
        expected_address: str
    ) -> bool:
        """
        Verify message signature

        Args:
            message: Original message
            signature: Signature to verify
            expected_address: Expected signer address

        Returns:
            True if signature is valid
        """
        message_hash = self.w3.keccak(text=message)
        recovered_address = Account.recover_message(
            message_hash, signature=signature
        )

        return recovered_address.lower() == expected_address.lower()


def main():
    """Example usage"""

    # Initialize wallet manager
    manager = WalletManager()

    # Create new account
    print("\n=== Creating New Account ===")
    account = manager.create_account()
    print(f"Address: {account['address']}")
    print(f"Private Key: {account['private_key']}")
    print("⚠️  NEVER share your private key!")

    # Check balance
    print("\n=== Checking Balance ===")
    balance = manager.get_balance(account['address'])
    print(f"Balance: {balance} ETH")

    # Get gas price
    print("\n=== Gas Price ===")
    gas_prices = manager.get_gas_price()
    print(f"Current gas price: {gas_prices['gwei']} Gwei")

    # Sign message
    print("\n=== Message Signing ===")
    message = "Hello, Web3!"
    signature = manager.sign_message(message, account['private_key'])
    print(f"Message: {message}")
    print(f"Signature: {signature}")

    # Verify signature
    is_valid = manager.verify_signature(
        message, signature, account['address']
    )
    print(f"Signature valid: {is_valid}")


if __name__ == "__main__":
    main()
