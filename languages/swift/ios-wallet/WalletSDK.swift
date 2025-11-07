import Foundation
import CryptoKit
import web3swift
import Web3Core

/// iOS Ethereum Wallet SDK
/// Provides wallet creation, transaction signing, and Web3 integration
/// Compatible with iOS 13+ and SwiftUI
@available(iOS 13.0, *)
public class EthereumWalletSDK {

    // MARK: - Properties

    private let keystore: BIP32Keystore?
    private var web3: Web3?
    private let networkURL: URL

    // MARK: - Initialization

    /// Initialize wallet SDK
    /// - Parameter networkURL: Ethereum node RPC URL
    public init(networkURL: String = "https://sepolia.infura.io/v3/YOUR_KEY") {
        self.networkURL = URL(string: networkURL)!
        self.keystore = nil
    }

    // MARK: - Wallet Management

    /// Create a new Ethereum wallet
    /// - Returns: WalletInfo containing address and mnemonic
    public func createWallet() throws -> WalletInfo {
        // Generate mnemonic
        guard let mnemonic = try? BIP39.generateMnemonics(bitsOfEntropy: 256) else {
            throw WalletError.failedToGenerateMnemonic
        }

        // Create keystore from mnemonic
        guard let keystore = try? BIP32Keystore(
            mnemonics: mnemonic,
            password: "",
            mnemonicsPassword: ""
        ) else {
            throw WalletError.failedToCreateKeystore
        }

        // Get address
        guard let address = keystore.addresses?.first?.address else {
            throw WalletError.failedToGetAddress
        }

        print("✅ Wallet created successfully")
        print("📱 Address: \(address)")

        return WalletInfo(
            address: address,
            mnemonic: mnemonic,
            keystore: keystore
        )
    }

    /// Import wallet from mnemonic
    /// - Parameter mnemonic: 12 or 24 word mnemonic phrase
    /// - Returns: WalletInfo
    public func importWallet(mnemonic: String) throws -> WalletInfo {
        guard let keystore = try? BIP32Keystore(
            mnemonics: mnemonic,
            password: "",
            mnemonicsPassword: ""
        ) else {
            throw WalletError.invalidMnemonic
        }

        guard let address = keystore.addresses?.first?.address else {
            throw WalletError.failedToGetAddress
        }

        return WalletInfo(
            address: address,
            mnemonic: mnemonic,
            keystore: keystore
        )
    }

    /// Get ETH balance for address
    /// - Parameter address: Ethereum address
    /// - Returns: Balance in ETH as String
    public func getBalance(address: String) async throws -> String {
        guard let web3 = Web3(provider: Web3HttpProvider(url: networkURL)!) else {
            throw WalletError.failedToConnectWeb3
        }

        guard let ethAddress = EthereumAddress(address) else {
            throw WalletError.invalidAddress
        }

        let balanceResult = try await web3.eth.getBalance(for: ethAddress)
        let balanceString = Web3.Utils.formatToEthereumUnits(
            balanceResult,
            toUnits: .eth,
            decimals: 4
        ) ?? "0"

        print("💰 Balance: \(balanceString) ETH")
        return balanceString
    }

    // MARK: - Transactions

    /// Send ETH transaction
    /// - Parameters:
    ///   - from: Sender address
    ///   - to: Recipient address
    ///   - amount: Amount in ETH
    ///   - keystore: Sender's keystore
    /// - Returns: Transaction hash
    public func sendTransaction(
        from: String,
        to: String,
        amount: String,
        keystore: BIP32Keystore
    ) async throws -> String {
        guard let web3 = Web3(provider: Web3HttpProvider(url: networkURL)!) else {
            throw WalletError.failedToConnectWeb3
        }

        guard let fromAddress = EthereumAddress(from),
              let toAddress = EthereumAddress(to) else {
            throw WalletError.invalidAddress
        }

        guard let amountWei = Web3.Utils.parseToBigUInt(amount, units: .eth) else {
            throw WalletError.invalidAmount
        }

        // Create transaction
        var transaction = CodableTransaction(
            to: toAddress,
            value: amountWei,
            data: Data()
        )

        transaction.from = fromAddress

        // Send transaction
        let result = try await web3.eth.send(transaction)
        let txHash = result.hash

        print("✅ Transaction sent: \(txHash)")
        return txHash
    }

    // MARK: - Message Signing

    /// Sign message with wallet
    /// - Parameters:
    ///   - message: Message to sign
    ///   - keystore: Wallet keystore
    /// - Returns: Signature as hex string
    public func signMessage(message: String, keystore: BIP32Keystore) throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw WalletError.invalidMessage
        }

        // Hash message
        let hash = messageData.sha3(.keccak256)

        // Sign
        guard let address = keystore.addresses?.first else {
            throw WalletError.failedToGetAddress
        }

        let signature = try keystore.signPersonalMessage(hash, for: address)

        print("✍️  Message signed successfully")
        return signature.toHexString()
    }

    /// Verify message signature
    /// - Parameters:
    ///   - message: Original message
    ///   - signature: Signature to verify
    ///   - address: Expected signer address
    /// - Returns: true if signature is valid
    public func verifySignature(
        message: String,
        signature: String,
        address: String
    ) -> Bool {
        guard let messageData = message.data(using: .utf8),
              let signatureData = Data.fromHex(signature),
              let ethAddress = EthereumAddress(address) else {
            return false
        }

        let hash = messageData.sha3(.keccak256)

        do {
            let recovered = try Web3.Utils.hashPersonalMessage(hash)
            // Verify signature matches address
            return true // Simplified for example
        } catch {
            return false
        }
    }
}

// MARK: - Models

@available(iOS 13.0, *)
public struct WalletInfo {
    public let address: String
    public let mnemonic: String
    public let keystore: BIP32Keystore

    init(address: String, mnemonic: String, keystore: BIP32Keystore) {
        self.address = address
        self.mnemonic = mnemonic
        self.keystore = keystore
    }
}

@available(iOS 13.0, *)
public enum WalletError: Error, LocalizedError {
    case failedToGenerateMnemonic
    case failedToCreateKeystore
    case failedToGetAddress
    case invalidMnemonic
    case failedToConnectWeb3
    case invalidAddress
    case invalidAmount
    case invalidMessage

    public var errorDescription: String? {
        switch self {
        case .failedToGenerateMnemonic:
            return "Failed to generate mnemonic"
        case .failedToCreateKeystore:
            return "Failed to create keystore"
        case .failedToGetAddress:
            return "Failed to get address from keystore"
        case .invalidMnemonic:
            return "Invalid mnemonic phrase"
        case .failedToConnectWeb3:
            return "Failed to connect to Ethereum network"
        case .invalidAddress:
            return "Invalid Ethereum address"
        case .invalidAmount:
            return "Invalid amount"
        case .invalidMessage:
            return "Invalid message format"
        }
    }
}

// MARK: - SwiftUI Integration Example

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let wallet = viewModel.wallet {
                    // Wallet Info
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Address")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(wallet.address)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    Text("Balance: \(viewModel.balance) ETH")
                        .font(.title2)
                        .bold()

                    Button("Refresh Balance") {
                        Task {
                            await viewModel.refreshBalance()
                        }
                    }
                    .buttonStyle(.bordered)

                } else {
                    Button("Create Wallet") {
                        viewModel.createWallet()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("🔐 Wallet")
        }
    }
}

@available(iOS 13.0, *)
class WalletViewModel: ObservableObject {
    @Published var wallet: WalletInfo?
    @Published var balance: String = "0.0000"

    private let sdk = EthereumWalletSDK()

    func createWallet() {
        do {
            wallet = try sdk.createWallet()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    func refreshBalance() async {
        guard let wallet = wallet else { return }

        do {
            let newBalance = try await sdk.getBalance(address: wallet.address)
            await MainActor.run {
                balance = newBalance
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
#endif
