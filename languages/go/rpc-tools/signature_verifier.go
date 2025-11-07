package main

import (
	"crypto/ecdsa"
	"encoding/hex"
	"errors"
	"fmt"
	"log"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
)

// SignatureVerifier handles Ethereum signature verification
type SignatureVerifier struct{}

// NewSignatureVerifier creates a new signature verifier instance
func NewSignatureVerifier() *SignatureVerifier {
	return &SignatureVerifier{}
}

// VerifySignature verifies an Ethereum signature
func (sv *SignatureVerifier) VerifySignature(message, signature, address string) (bool, error) {
	// Hash the message
	hash := crypto.Keccak256Hash([]byte(message))

	// Decode signature
	sigBytes, err := hexutil.Decode(signature)
	if err != nil {
		return false, fmt.Errorf("failed to decode signature: %w", err)
	}

	// Ensure signature is 65 bytes
	if len(sigBytes) != 65 {
		return false, errors.New("invalid signature length")
	}

	// Adjust V value (EIP-155)
	if sigBytes[64] >= 27 {
		sigBytes[64] -= 27
	}

	// Recover public key
	pubKey, err := crypto.SigToPub(hash.Bytes(), sigBytes)
	if err != nil {
		return false, fmt.Errorf("failed to recover public key: %w", err)
	}

	// Get address from public key
	recoveredAddress := crypto.PubkeyToAddress(*pubKey)

	// Compare addresses
	expectedAddress := common.HexToAddress(address)

	return recoveredAddress == expectedAddress, nil
}

// SignMessage signs a message with a private key
func (sv *SignatureVerifier) SignMessage(message string, privateKeyHex string) (string, error) {
	// Remove 0x prefix if present
	if len(privateKeyHex) > 2 && privateKeyHex[:2] == "0x" {
		privateKeyHex = privateKeyHex[2:]
	}

	// Decode private key
	privateKeyBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return "", fmt.Errorf("failed to decode private key: %w", err)
	}

	// Create ECDSA private key
	privateKey, err := crypto.ToECDSA(privateKeyBytes)
	if err != nil {
		return "", fmt.Errorf("failed to create private key: %w", err)
	}

	// Hash the message
	hash := crypto.Keccak256Hash([]byte(message))

	// Sign the hash
	signature, err := crypto.Sign(hash.Bytes(), privateKey)
	if err != nil {
		return "", fmt.Errorf("failed to sign message: %w", err)
	}

	// Adjust V value for Ethereum
	signature[64] += 27

	return hexutil.Encode(signature), nil
}

// GetAddressFromPrivateKey derives Ethereum address from private key
func (sv *SignatureVerifier) GetAddressFromPrivateKey(privateKeyHex string) (string, error) {
	// Remove 0x prefix if present
	if len(privateKeyHex) > 2 && privateKeyHex[:2] == "0x" {
		privateKeyHex = privateKeyHex[2:]
	}

	// Decode private key
	privateKeyBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return "", fmt.Errorf("failed to decode private key: %w", err)
	}

	// Create ECDSA private key
	privateKey, err := crypto.ToECDSA(privateKeyBytes)
	if err != nil {
		return "", fmt.Errorf("failed to create private key: %w", err)
	}

	// Get public key
	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return "", errors.New("failed to cast public key to ECDSA")
	}

	// Get address
	address := crypto.PubkeyToAddress(*publicKeyECDSA)

	return address.Hex(), nil
}

// GeneratePrivateKey generates a new Ethereum private key
func (sv *SignatureVerifier) GeneratePrivateKey() (privateKey string, address string, err error) {
	// Generate new private key
	key, err := crypto.GenerateKey()
	if err != nil {
		return "", "", fmt.Errorf("failed to generate key: %w", err)
	}

	// Get private key bytes
	privateKeyBytes := crypto.FromECDSA(key)
	privateKeyHex := hexutil.Encode(privateKeyBytes)

	// Get address
	publicKey := key.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return "", "", errors.New("failed to cast public key to ECDSA")
	}

	addressHex := crypto.PubkeyToAddress(*publicKeyECDSA).Hex()

	return privateKeyHex, addressHex, nil
}

// HashMessage returns Keccak256 hash of a message
func (sv *SignatureVerifier) HashMessage(message string) string {
	hash := crypto.Keccak256Hash([]byte(message))
	return hash.Hex()
}

func main() {
	verifier := NewSignatureVerifier()

	fmt.Println("🔐 Ethereum Signature Verifier\n")

	// Generate new key pair
	fmt.Println("=== Generating New Key Pair ===")
	privateKey, address, err := verifier.GeneratePrivateKey()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Private Key: %s\n", privateKey)
	fmt.Printf("Address: %s\n", address)

	// Sign a message
	fmt.Println("\n=== Signing Message ===")
	message := "Hello, Ethereum!"
	signature, err := verifier.SignMessage(message, privateKey)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Message: %s\n", message)
	fmt.Printf("Signature: %s\n", signature)

	// Verify signature
	fmt.Println("\n=== Verifying Signature ===")
	isValid, err := verifier.VerifySignature(message, signature, address)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Signature Valid: %v\n", isValid)

	// Hash message
	fmt.Println("\n=== Hashing Message ===")
	hash := verifier.HashMessage(message)
	fmt.Printf("Keccak256 Hash: %s\n", hash)

	fmt.Println("\n✅ All operations completed successfully!")
}
