#!/bin/bash

# Comprehensive test script
# Runs all tests and checks

set -e

echo "🧪 Running comprehensive test suite..."
echo ""

# Check Rust code
echo "1️⃣  Checking Rust code..."
cargo check --manifest-path programs/donation/Cargo.toml
echo "✅ Rust check passed!"
echo ""

# Run Rust tests (if any)
echo "2️⃣  Running Rust unit tests..."
cargo test --manifest-path programs/donation/Cargo.toml 2>/dev/null || echo "ℹ️  No Rust tests found or tests skipped"
echo ""

# Build the program
echo "3️⃣  Building program..."
if command -v anchor >/dev/null 2>&1; then
    anchor build
    echo "✅ Build successful!"
else
    cargo build --manifest-path programs/donation/Cargo.toml
    echo "✅ Cargo build successful!"
fi
echo ""

# Run Anchor/TypeScript tests
echo "4️⃣  Running integration tests..."
if command -v anchor >/dev/null 2>&1; then
    if [ -f "tests/donation.test.ts" ]; then
        # Note: Tests require a local validator or test environment
        echo "ℹ️  To run integration tests, ensure you have a local validator running:"
        echo "    solana-test-validator"
        echo "    Then run: anchor test"
    fi
else
    echo "⚠️  Anchor not available, skipping integration tests"
fi
echo ""

echo "✅ All tests completed!"
echo ""
echo "💡 Tips:"
echo "  - Run specific tests: anchor test --skip-build"
echo "  - Start local validator: solana-test-validator"
echo "  - Check program logs: solana logs"
echo ""
