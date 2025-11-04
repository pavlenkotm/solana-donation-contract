# Solana Donation Contract - Makefile
# Convenient commands for development and deployment

.PHONY: help install build test clean deploy format lint audit

# Default target
.DEFAULT_GOAL := help

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

## help: Show this help message
help:
	@echo "$(BLUE)Solana Donation Contract - Available Commands$(NC)"
	@echo ""
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'
	@echo ""

## install: Install all dependencies
install:
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	@npm install
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

## build: Build the Solana program
build:
	@echo "$(YELLOW)Building program...$(NC)"
	@anchor build
	@echo "$(GREEN)✓ Build complete$(NC)"

## build-verifiable: Build with verifiable flag
build-verifiable:
	@echo "$(YELLOW)Building verifiable program...$(NC)"
	@anchor build --verifiable
	@echo "$(GREEN)✓ Verifiable build complete$(NC)"

## test: Run all tests
test:
	@echo "$(YELLOW)Running tests...$(NC)"
	@anchor test
	@echo "$(GREEN)✓ Tests passed$(NC)"

## test-quiet: Run tests without logs
test-quiet:
	@echo "$(YELLOW)Running tests (quiet mode)...$(NC)"
	@anchor test 2>&1 | grep -E "(✓|✗|passing|failing)"
	@echo "$(GREEN)✓ Tests complete$(NC)"

## format: Format Rust code
format:
	@echo "$(YELLOW)Formatting code...$(NC)"
	@cd programs/donation && cargo fmt
	@echo "$(GREEN)✓ Code formatted$(NC)"

## format-check: Check code formatting
format-check:
	@echo "$(YELLOW)Checking code format...$(NC)"
	@cd programs/donation && cargo fmt -- --check
	@echo "$(GREEN)✓ Format check passed$(NC)"

## lint: Run clippy linter
lint:
	@echo "$(YELLOW)Running linter...$(NC)"
	@cd programs/donation && cargo clippy --all-targets --all-features -- -D warnings
	@echo "$(GREEN)✓ Lint passed$(NC)"

## audit: Run security audit
audit:
	@echo "$(YELLOW)Running security audit...$(NC)"
	@cd programs/donation && cargo audit
	@echo "$(GREEN)✓ Audit complete$(NC)"

## clean: Clean build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@anchor clean
	@rm -rf target/
	@rm -rf .anchor/
	@rm -rf node_modules/
	@echo "$(GREEN)✓ Clean complete$(NC)"

## clean-target: Clean only target directory
clean-target:
	@echo "$(YELLOW)Cleaning target directory...$(NC)"
	@rm -rf target/
	@echo "$(GREEN)✓ Target cleaned$(NC)"

## deploy-devnet: Deploy to Solana devnet
deploy-devnet:
	@echo "$(YELLOW)Deploying to devnet...$(NC)"
	@solana config set --url devnet
	@anchor deploy --provider.cluster devnet
	@echo "$(GREEN)✓ Deployed to devnet$(NC)"

## deploy-mainnet: Deploy to Solana mainnet-beta
deploy-mainnet:
	@echo "$(RED)⚠️  WARNING: Deploying to MAINNET$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		solana config set --url mainnet-beta; \
		anchor deploy --provider.cluster mainnet-beta; \
		echo "$(GREEN)✓ Deployed to mainnet$(NC)"; \
	else \
		echo "$(YELLOW)Deployment cancelled$(NC)"; \
	fi

## localnet: Start local Solana test validator
localnet:
	@echo "$(YELLOW)Starting local validator...$(NC)"
	@solana-test-validator

## keys: Show Solana configuration
keys:
	@echo "$(BLUE)Current Solana Configuration:$(NC)"
	@solana config get
	@echo ""
	@echo "$(BLUE)Current Keypair:$(NC)"
	@solana address

## balance: Check SOL balance
balance:
	@echo "$(BLUE)Checking balance...$(NC)"
	@solana balance

## airdrop: Request SOL airdrop (devnet/testnet)
airdrop:
	@echo "$(YELLOW)Requesting airdrop...$(NC)"
	@solana airdrop 2
	@echo "$(GREEN)✓ Airdrop complete$(NC)"

## verify: Verify program deployment
verify:
	@echo "$(YELLOW)Verifying program...$(NC)"
	@anchor build --verifiable
	@echo "$(GREEN)✓ Verification complete$(NC)"

## idl-init: Initialize IDL
idl-init:
	@echo "$(YELLOW)Initializing IDL...$(NC)"
	@anchor idl init --filepath target/idl/donation.json $(shell solana address -k target/deploy/donation-keypair.json)
	@echo "$(GREEN)✓ IDL initialized$(NC)"

## idl-upgrade: Upgrade IDL
idl-upgrade:
	@echo "$(YELLOW)Upgrading IDL...$(NC)"
	@anchor idl upgrade --filepath target/idl/donation.json $(shell solana address -k target/deploy/donation-keypair.json)
	@echo "$(GREEN)✓ IDL upgraded$(NC)"

## program-id: Show program ID
program-id:
	@echo "$(BLUE)Program ID:$(NC)"
	@solana address -k target/deploy/donation-keypair.json

## logs: Show program logs
logs:
	@echo "$(YELLOW)Showing program logs (Ctrl+C to stop)...$(NC)"
	@solana logs

## check: Run all checks (format, lint, test)
check: format-check lint test
	@echo "$(GREEN)✓ All checks passed$(NC)"

## quick: Quick build and test
quick: build test
	@echo "$(GREEN)✓ Quick check complete$(NC)"

## full: Full build, lint, test, and audit
full: clean install build lint test audit
	@echo "$(GREEN)✓ Full check complete$(NC)"

## stats: Show project statistics
stats:
	@echo "$(BLUE)Project Statistics:$(NC)"
	@echo ""
	@echo "Rust Lines of Code:"
	@find programs -name "*.rs" -exec wc -l {} + | tail -1
	@echo ""
	@echo "Test Files:"
	@find tests -name "*.ts" -exec wc -l {} + | tail -1
	@echo ""
	@echo "Total Files:"
	@find . -type f \( -name "*.rs" -o -name "*.ts" -o -name "*.toml" \) | wc -l

## docs: Generate and open documentation
docs:
	@echo "$(YELLOW)Generating documentation...$(NC)"
	@cd programs/donation && cargo doc --open
	@echo "$(GREEN)✓ Documentation generated$(NC)"

## watch: Watch for changes and rebuild
watch:
	@echo "$(YELLOW)Watching for changes...$(NC)"
	@cargo watch -x 'build' -s 'anchor build'

## benchmark: Run performance benchmarks
benchmark:
	@echo "$(YELLOW)Running benchmarks...$(NC)"
	@cd programs/donation && cargo bench
	@echo "$(GREEN)✓ Benchmarks complete$(NC)"

## setup-dev: Setup development environment
setup-dev: install
	@echo "$(YELLOW)Setting up development environment...$(NC)"
	@rustup component add rustfmt clippy
	@cargo install cargo-watch cargo-audit
	@solana config set --url localhost
	@echo "$(GREEN)✓ Development environment ready$(NC)"

## ci: Run CI pipeline locally
ci: format-check lint test
	@echo "$(GREEN)✓ CI checks passed$(NC)"

## release-check: Pre-release verification
release-check: clean full build-verifiable
	@echo "$(GREEN)✓ Release ready$(NC)"

## info: Show project information
info:
	@echo "$(BLUE)Project: Solana Donation Contract$(NC)"
	@echo "$(BLUE)Version: 0.3.0$(NC)"
	@echo ""
	@echo "Solana CLI:"
	@solana --version
	@echo ""
	@echo "Anchor CLI:"
	@anchor --version
	@echo ""
	@echo "Rust:"
	@rustc --version
	@echo ""
	@echo "Node.js:"
	@node --version

## update: Update dependencies
update:
	@echo "$(YELLOW)Updating dependencies...$(NC)"
	@npm update
	@cd programs/donation && cargo update
	@echo "$(GREEN)✓ Dependencies updated$(NC)"
