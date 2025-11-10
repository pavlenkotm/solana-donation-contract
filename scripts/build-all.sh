#!/bin/bash

# Build script for all components
# Builds the Solana program and TypeScript code

set -e

echo "🏗️  Building all components..."
echo ""

# Build Solana program with Anchor
echo "1️⃣  Building Solana program..."
if command -v anchor >/dev/null 2>&1; then
    anchor build
    echo "✅ Anchor build complete!"
else
    echo "⚠️  Anchor not found, using cargo..."
    cargo build --release --manifest-path programs/donation/Cargo.toml
    echo "✅ Cargo build complete!"
fi
echo ""

# Build TypeScript
echo "2️⃣  Compiling TypeScript..."
if command -v tsc >/dev/null 2>&1; then
    npx tsc --noEmit
    echo "✅ TypeScript compilation check complete!"
else
    echo "⚠️  TypeScript compiler not found, skipping..."
fi
echo ""

# Run linter
echo "3️⃣  Running linter..."
npm run lint --if-present 2>/dev/null || echo "ℹ️  Linter not configured or not available"
echo ""

echo "✨ All builds complete!"
echo ""
echo "📦 Artifacts:"
echo "  - Solana program: target/deploy/donation.so"
echo "  - Program IDL: target/idl/donation.json"
echo ""
echo "🧪 Run tests with: npm test"
echo "🚀 Deploy with: npm run deploy:devnet"
echo ""
