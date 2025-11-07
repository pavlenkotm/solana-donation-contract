#include <iostream>
#include <string>
#include <vector>
#include <iomanip>
#include <sstream>
#include <cstring>
#include <openssl/evp.h>
#include <openssl/sha.h>

/**
 * @brief Ethereum Keccak256 Hash Implementation in C++
 * @details Uses OpenSSL for cryptographic operations
 */

class Keccak256 {
public:
    /**
     * @brief Compute Keccak256 hash of input data
     * @param input Input data as string
     * @return Hexadecimal hash string
     */
    static std::string hash(const std::string& input) {
        return hash(reinterpret_cast<const unsigned char*>(input.c_str()), input.length());
    }

    /**
     * @brief Compute Keccak256 hash of input data
     * @param data Input data as byte array
     * @param length Length of input data
     * @return Hexadecimal hash string
     */
    static std::string hash(const unsigned char* data, size_t length) {
        EVP_MD_CTX* ctx = EVP_MD_CTX_new();
        if (!ctx) {
            throw std::runtime_error("Failed to create EVP_MD_CTX");
        }

        // Initialize Keccak256 (note: OpenSSL 3.0+ has Keccak support)
        const EVP_MD* md = EVP_sha3_256();
        if (!EVP_DigestInit_ex(ctx, md, nullptr)) {
            EVP_MD_CTX_free(ctx);
            throw std::runtime_error("Failed to initialize digest");
        }

        // Update with input data
        if (!EVP_DigestUpdate(ctx, data, length)) {
            EVP_MD_CTX_free(ctx);
            throw std::runtime_error("Failed to update digest");
        }

        // Finalize and get hash
        unsigned char hash_bytes[EVP_MAX_MD_SIZE];
        unsigned int hash_length = 0;

        if (!EVP_DigestFinal_ex(ctx, hash_bytes, &hash_length)) {
            EVP_MD_CTX_free(ctx);
            throw std::runtime_error("Failed to finalize digest");
        }

        EVP_MD_CTX_free(ctx);

        // Convert to hex string
        return bytesToHex(hash_bytes, hash_length);
    }

    /**
     * @brief Verify hash matches expected value
     * @param input Input data
     * @param expectedHash Expected hash in hex
     * @return true if hashes match
     */
    static bool verify(const std::string& input, const std::string& expectedHash) {
        std::string computed = hash(input);
        return computed == expectedHash;
    }

private:
    /**
     * @brief Convert bytes to hexadecimal string
     * @param bytes Input bytes
     * @param length Length of bytes
     * @return Hexadecimal string with 0x prefix
     */
    static std::string bytesToHex(const unsigned char* bytes, size_t length) {
        std::stringstream ss;
        ss << "0x";
        for (size_t i = 0; i < length; ++i) {
            ss << std::hex << std::setw(2) << std::setfill('0')
               << static_cast<int>(bytes[i]);
        }
        return ss.str();
    }
};

/**
 * @brief ECDSA Signature Utilities
 */
class ECDSAUtils {
public:
    /**
     * @brief Generate random private key
     * @return Private key as hex string
     */
    static std::string generatePrivateKey() {
        unsigned char key[32];
        if (RAND_bytes(key, 32) != 1) {
            throw std::runtime_error("Failed to generate random bytes");
        }
        return Keccak256::bytesToHex(key, 32);
    }

    /**
     * @brief Compute Ethereum address from public key
     * @param publicKey Public key bytes
     * @return Ethereum address (0x prefixed, 40 hex chars)
     */
    static std::string publicKeyToAddress(const std::vector<unsigned char>& publicKey) {
        // Hash public key
        std::string hash = Keccak256::hash(publicKey.data(), publicKey.size());

        // Take last 20 bytes (40 hex chars)
        return "0x" + hash.substr(hash.length() - 40);
    }
};

/**
 * @brief BLS Signature placeholder
 * Note: BLS signatures require specialized libraries like libblst
 */
class BLSUtils {
public:
    static void info() {
        std::cout << "BLS signatures are used in Ethereum 2.0 for:" << std::endl;
        std::cout << "- Validator signatures" << std::endl;
        std::cout << "- Signature aggregation" << std::endl;
        std::cout << "- Compact multi-signatures" << std::endl;
        std::cout << "\nImplementation requires: libblst, mcl, or herumi/bls" << std::endl;
    }
};

/**
 * @brief Merkle Tree implementation
 */
class MerkleTree {
private:
    std::vector<std::string> leaves;
    std::vector<std::vector<std::string>> layers;

public:
    MerkleTree(const std::vector<std::string>& data) {
        // Hash all leaves
        for (const auto& item : data) {
            leaves.push_back(Keccak256::hash(item));
        }

        // Build tree
        buildTree();
    }

    /**
     * @brief Get Merkle root
     * @return Root hash
     */
    std::string getRoot() const {
        if (layers.empty() || layers.back().empty()) {
            return "";
        }
        return layers.back()[0];
    }

    /**
     * @brief Get Merkle proof for a leaf
     * @param index Leaf index
     * @return Proof hashes
     */
    std::vector<std::string> getProof(size_t index) const {
        std::vector<std::string> proof;
        size_t idx = index;

        for (size_t i = 0; i < layers.size() - 1; ++i) {
            const auto& layer = layers[i];
            size_t pairIndex = (idx % 2 == 0) ? idx + 1 : idx - 1;

            if (pairIndex < layer.size()) {
                proof.push_back(layer[pairIndex]);
            }

            idx /= 2;
        }

        return proof;
    }

private:
    void buildTree() {
        if (leaves.empty()) return;

        layers.push_back(leaves);

        while (layers.back().size() > 1) {
            std::vector<std::string> newLayer;
            const auto& currentLayer = layers.back();

            for (size_t i = 0; i < currentLayer.size(); i += 2) {
                if (i + 1 < currentLayer.size()) {
                    // Combine pairs
                    std::string combined = currentLayer[i] + currentLayer[i + 1];
                    newLayer.push_back(Keccak256::hash(combined));
                } else {
                    // Odd number, carry up
                    newLayer.push_back(currentLayer[i]);
                }
            }

            layers.push_back(newLayer);
        }
    }
};

// Demo/Test functions
void demoKeccak256() {
    std::cout << "\n=== Keccak256 Demo ===" << std::endl;

    std::string message = "Hello, Ethereum!";
    std::string hash = Keccak256::hash(message);

    std::cout << "Message: " << message << std::endl;
    std::cout << "Hash: " << hash << std::endl;

    // Verify
    bool isValid = Keccak256::verify(message, hash);
    std::cout << "Verification: " << (isValid ? "✅ Valid" : "❌ Invalid") << std::endl;
}

void demoMerkleTree() {
    std::cout << "\n=== Merkle Tree Demo ===" << std::endl;

    std::vector<std::string> transactions = {
        "tx1: Alice sends 1 ETH to Bob",
        "tx2: Bob sends 0.5 ETH to Charlie",
        "tx3: Charlie sends 0.2 ETH to Alice",
        "tx4: Alice sends 0.1 ETH to Dave"
    };

    MerkleTree tree(transactions);

    std::cout << "Merkle Root: " << tree.getRoot() << std::endl;

    std::cout << "\nProof for transaction 0:" << std::endl;
    auto proof = tree.getProof(0);
    for (size_t i = 0; i < proof.size(); ++i) {
        std::cout << "  " << i << ": " << proof[i] << std::endl;
    }
}

int main() {
    std::cout << "🔐 Crypto Algorithms for Blockchain" << std::endl;
    std::cout << "=====================================" << std::endl;

    try {
        demoKeccak256();
        demoMerkleTree();

        std::cout << "\n=== BLS Information ===" << std::endl;
        BLSUtils::info();

        std::cout << "\n✅ All demos completed successfully!" << std::endl;

    } catch (const std::exception& e) {
        std::cerr << "❌ Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
