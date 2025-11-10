#!/bin/bash

# Setup script for Solana Donation Contract
# This script prepares the development environment

set -e

echo "🚀 Setting up Solana Donation Contract..."
echo ""

# Check for required tools
echo "📋 Checking dependencies..."

command -v node >/dev/null 2>&1 || { echo "❌ Node.js is required but not installed. Visit https://nodejs.org/"; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "❌ Rust/Cargo is required. Visit https://rustup.rs/"; exit 1; }
command -v solana >/dev/null 2>&1 || { echo "⚠️  Solana CLI not found. Visit https://docs.solana.com/cli/install-solana-cli-tools"; }
command -v anchor >/dev/null 2>&1 || { echo "⚠️  Anchor not found. Visit https://www.anchor-lang.com/docs/installation"; }

echo "✅ All required dependencies found!"
echo ""

# Install npm packages
echo "📦 Installing Node.js dependencies..."
npm install
echo "✅ Node.js dependencies installed!"
echo ""

# Build the program
echo "🔨 Building Solana program..."
if command -v anchor >/dev/null 2>&1; then
    anchor build
    echo "✅ Program built successfully!"
else
    echo "⚠️  Skipping Anchor build (Anchor CLI not installed)"
    cargo build --manifest-path programs/donation/Cargo.toml
    echo "✅ Cargo build completed!"
fi
echo ""

# Create keypairs directory if it doesn't exist
echo "🔑 Setting up keypairs directory..."
mkdir -p keypairs
echo "✅ Keypairs directory ready!"
echo ""

# Copy .env.example to .env if .env doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env file created! Please update it with your configuration."
else
    echo "ℹ️  .env file already exists"
fi
echo ""

# Show next steps
echo "✨ Setup complete!"
echo ""
echo "📚 Next steps:"
echo "  1. Configure your .env file with appropriate values"
echo "  2. Generate keypairs: solana-keygen new --outfile keypairs/admin.json"
echo "  3. Get devnet SOL: solana airdrop 2 <your-address> --url devnet"
echo "  4. Run tests: npm test"
echo "  5. Deploy to devnet: npm run deploy:devnet"
echo ""
echo "📖 See README.md for more detailed instructions"
echo ""
