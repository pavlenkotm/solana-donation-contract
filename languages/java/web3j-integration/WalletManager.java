package com.web3.showcase;

import org.web3j.crypto.*;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.DefaultBlockParameterName;
import org.web3j.protocol.core.methods.response.*;
import org.web3j.protocol.http.HttpService;
import org.web3j.tx.RawTransactionManager;
import org.web3j.tx.Transfer;
import org.web3j.utils.Convert;
import org.web3j.utils.Numeric;

import java.math.BigDecimal;
import java.math.BigInteger;
import java.security.SecureRandom;
import java.io.IOException;

/**
 * Ethereum Wallet Manager using Web3j
 * Demonstrates wallet operations, transactions, and smart contract interaction
 *
 * @author Web3 Showcase
 * @version 1.0.0
 */
public class WalletManager {

    private final Web3j web3j;
    private static final String INFURA_URL = "https://sepolia.infura.io/v3/YOUR_INFURA_KEY";

    /**
     * Constructor
     * @param nodeUrl Ethereum node RPC URL
     */
    public WalletManager(String nodeUrl) {
        this.web3j = Web3j.build(new HttpService(nodeUrl));
    }

    /**
     * Default constructor using Sepolia testnet
     */
    public WalletManager() {
        this(INFURA_URL);
    }

    /**
     * Create a new Ethereum wallet
     * @return WalletInfo containing address and private key
     */
    public WalletInfo createWallet() {
        try {
            // Generate new key pair using secure random
            ECKeyPair keyPair = Keys.createEcKeyPair(new SecureRandom());

            // Get wallet address
            String address = "0x" + Keys.getAddress(keyPair);

            // Get private key
            String privateKey = Numeric.toHexStringWithPrefix(keyPair.getPrivateKey());

            System.out.println("✅ Wallet created successfully");
            System.out.println("Address: " + address);

            return new WalletInfo(address, privateKey, keyPair);

        } catch (Exception e) {
            System.err.println("❌ Error creating wallet: " + e.getMessage());
            throw new RuntimeException("Failed to create wallet", e);
        }
    }

    /**
     * Load wallet from private key
     * @param privateKey Private key (with or without 0x prefix)
     * @return Credentials object
     */
    public Credentials loadWallet(String privateKey) {
        try {
            // Remove 0x prefix if present
            if (privateKey.startsWith("0x")) {
                privateKey = privateKey.substring(2);
            }

            BigInteger privateKeyBigInt = new BigInteger(privateKey, 16);
            ECKeyPair keyPair = ECKeyPair.create(privateKeyBigInt);

            return Credentials.create(keyPair);

        } catch (Exception e) {
            System.err.println("❌ Error loading wallet: " + e.getMessage());
            throw new RuntimeException("Failed to load wallet", e);
        }
    }

    /**
     * Get ETH balance for an address
     * @param address Ethereum address
     * @return Balance in ETH
     */
    public BigDecimal getBalance(String address) {
        try {
            EthGetBalance ethGetBalance = web3j
                    .ethGetBalance(address, DefaultBlockParameterName.LATEST)
                    .send();

            BigInteger balanceWei = ethGetBalance.getBalance();
            BigDecimal balanceEth = Convert.fromWei(
                    new BigDecimal(balanceWei),
                    Convert.Unit.ETHER
            );

            System.out.println("💰 Balance: " + balanceEth + " ETH");
            return balanceEth;

        } catch (IOException e) {
            System.err.println("❌ Error getting balance: " + e.getMessage());
            throw new RuntimeException("Failed to get balance", e);
        }
    }

    /**
     * Send ETH transaction
     * @param credentials Sender credentials
     * @param toAddress Recipient address
     * @param amountEth Amount in ETH
     * @return Transaction hash
     */
    public String sendTransaction(Credentials credentials, String toAddress, BigDecimal amountEth) {
        try {
            System.out.println("📤 Sending transaction...");

            // Send transaction
            TransactionReceipt receipt = Transfer.sendFunds(
                    web3j,
                    credentials,
                    toAddress,
                    amountEth,
                    Convert.Unit.ETHER
            ).send();

            String txHash = receipt.getTransactionHash();
            System.out.println("✅ Transaction sent: " + txHash);
            System.out.println("Gas used: " + receipt.getGasUsed());

            return txHash;

        } catch (Exception e) {
            System.err.println("❌ Error sending transaction: " + e.getMessage());
            throw new RuntimeException("Failed to send transaction", e);
        }
    }

    /**
     * Get transaction details
     * @param txHash Transaction hash
     * @return Transaction object
     */
    public Transaction getTransaction(String txHash) {
        try {
            EthTransaction ethTransaction = web3j
                    .ethGetTransactionByHash(txHash)
                    .send();

            if (ethTransaction.getTransaction().isPresent()) {
                Transaction tx = ethTransaction.getTransaction().get();
                System.out.println("📋 Transaction details:");
                System.out.println("  From: " + tx.getFrom());
                System.out.println("  To: " + tx.getTo());
                System.out.println("  Value: " + Convert.fromWei(
                        new BigDecimal(tx.getValue()),
                        Convert.Unit.ETHER
                ) + " ETH");
                return tx;
            } else {
                throw new RuntimeException("Transaction not found");
            }

        } catch (IOException e) {
            System.err.println("❌ Error getting transaction: " + e.getMessage());
            throw new RuntimeException("Failed to get transaction", e);
        }
    }

    /**
     * Sign a message
     * @param message Message to sign
     * @param credentials Signing credentials
     * @return Signature
     */
    public String signMessage(String message, Credentials credentials) {
        try {
            // Hash message
            byte[] messageBytes = message.getBytes();
            byte[] messageHash = Hash.sha3(messageBytes);

            // Sign
            Sign.SignatureData signature = Sign.signMessage(
                    messageHash,
                    credentials.getEcKeyPair(),
                    false
            );

            // Combine r, s, v
            byte[] signatureBytes = new byte[65];
            System.arraycopy(signature.getR(), 0, signatureBytes, 0, 32);
            System.arraycopy(signature.getS(), 0, signatureBytes, 32, 32);
            System.arraycopy(signature.getV(), 0, signatureBytes, 64, 1);

            String signatureHex = Numeric.toHexString(signatureBytes);
            System.out.println("✍️  Signature: " + signatureHex);

            return signatureHex;

        } catch (Exception e) {
            System.err.println("❌ Error signing message: " + e.getMessage());
            throw new RuntimeException("Failed to sign message", e);
        }
    }

    /**
     * Get current gas price
     * @return Gas price in Gwei
     */
    public BigInteger getGasPrice() {
        try {
            EthGasPrice gasPrice = web3j.ethGasPrice().send();
            BigInteger gasPriceWei = gasPrice.getGasPrice();
            BigDecimal gasPriceGwei = Convert.fromWei(
                    new BigDecimal(gasPriceWei),
                    Convert.Unit.GWEI
            );

            System.out.println("⛽ Gas price: " + gasPriceGwei + " Gwei");
            return gasPriceWei;

        } catch (IOException e) {
            System.err.println("❌ Error getting gas price: " + e.getMessage());
            throw new RuntimeException("Failed to get gas price", e);
        }
    }

    /**
     * Wallet information class
     */
    public static class WalletInfo {
        private final String address;
        private final String privateKey;
        private final ECKeyPair keyPair;

        public WalletInfo(String address, String privateKey, ECKeyPair keyPair) {
            this.address = address;
            this.privateKey = privateKey;
            this.keyPair = keyPair;
        }

        public String getAddress() { return address; }
        public String getPrivateKey() { return privateKey; }
        public ECKeyPair getKeyPair() { return keyPair; }
    }

    /**
     * Demo/Test main method
     */
    public static void main(String[] args) {
        System.out.println("🔐 Ethereum Wallet Manager - Web3j");
        System.out.println("===================================\n");

        try {
            WalletManager manager = new WalletManager();

            // Create new wallet
            System.out.println("=== Creating New Wallet ===");
            WalletInfo wallet = manager.createWallet();
            System.out.println();

            // Get balance
            System.out.println("=== Checking Balance ===");
            manager.getBalance(wallet.getAddress());
            System.out.println();

            // Get gas price
            System.out.println("=== Gas Price ===");
            manager.getGasPrice();
            System.out.println();

            // Sign message
            System.out.println("=== Signing Message ===");
            Credentials credentials = Credentials.create(wallet.getKeyPair());
            String message = "Hello, Web3j!";
            System.out.println("Message: " + message);
            manager.signMessage(message, credentials);

            System.out.println("\n✅ All operations completed successfully!");

        } catch (Exception e) {
            System.err.println("❌ Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
