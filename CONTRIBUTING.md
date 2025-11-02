# Contributing to Solana Donation Contract

First off, thank you for considering contributing to the Solana Donation Contract! It's people like you that make this project better for everyone.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

## Code of Conduct

This project adheres to a simple code of conduct:
- Be respectful and inclusive
- Provide constructive feedback
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:
- Rust 1.75.0 or higher
- Solana CLI 1.18.0 or higher
- Anchor CLI 0.30.1 or higher
- Node.js 18+ (for testing)
- Git

### Development Setup

1. **Fork the repository**
   ```bash
   # Click the "Fork" button on GitHub
   ```

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/solana-donation-contract.git
   cd solana-donation-contract
   ```

3. **Add upstream remote**
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/solana-donation-contract.git
   ```

4. **Install dependencies**
   ```bash
   npm install
   ```

5. **Build the project**
   ```bash
   anchor build
   ```

6. **Run tests**
   ```bash
   anchor test
   ```

## How to Contribute

### Types of Contributions

We welcome many types of contributions:

1. **Bug Fixes** - Fix issues in the code
2. **Features** - Add new functionality
3. **Documentation** - Improve or add documentation
4. **Tests** - Add or improve test coverage
5. **Examples** - Create usage examples
6. **Performance** - Optimize existing code
7. **Security** - Identify and fix security issues

### Contribution Workflow

1. **Create an issue** (if one doesn't exist)
   - Describe the bug/feature
   - Discuss the approach
   - Get feedback before starting work

2. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

3. **Make your changes**
   - Write clean, well-documented code
   - Follow coding standards
   - Add tests for new functionality
   - Update documentation

4. **Test your changes**
   ```bash
   anchor test
   cargo clippy -- -D warnings
   cargo fmt --check
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request**
   - Use a clear title and description
   - Reference related issues
   - Add screenshots/examples if applicable

## Coding Standards

### Rust Code Style

Follow the official Rust style guide:

```rust
// Good: Clear, documented function
/// Calculate donor tier based on total donations
///
/// # Arguments
/// * `total_donated` - Total amount donated by a donor in lamports
///
/// # Returns
/// * `DonorTier` - The calculated tier
fn calculate_tier(total_donated: u64) -> DonorTier {
    if total_donated >= TIER_PLATINUM {
        DonorTier::Platinum
    } else if total_donated >= TIER_GOLD {
        DonorTier::Gold
    } else if total_donated >= TIER_SILVER {
        DonorTier::Silver
    } else {
        DonorTier::Bronze
    }
}
```

### Key Principles

1. **Documentation**
   - All public functions must have doc comments
   - Use `///` for documentation
   - Include examples where helpful

2. **Error Handling**
   - Use descriptive error messages
   - Handle all error cases
   - Use `Result<T>` return types

3. **Security**
   - Use checked arithmetic (`.checked_add()`, `.checked_sub()`)
   - Validate all inputs
   - Verify admin authorization
   - Maintain rent exemption

4. **Naming Conventions**
   - Use snake_case for functions and variables
   - Use PascalCase for types and structs
   - Use SCREAMING_SNAKE_CASE for constants
   - Use descriptive names

5. **Code Organization**
   - Group related functions together
   - Use sections with comments
   - Keep functions focused and small

### Example Good Code

```rust
/// Update donation limits (admin only)
///
/// # Arguments
/// * `ctx` - The context containing all accounts
/// * `min_amount` - New minimum donation amount
/// * `max_amount` - New maximum donation amount
///
/// # Returns
/// * `Result<()>` - Success or error
///
/// # Errors
/// * `DonationError::Unauthorized` - If caller is not admin
/// * `DonationError::InvalidAmount` - If min >= max
pub fn update_donation_limits(
    ctx: Context<UpdateAdmin>,
    min_amount: u64,
    max_amount: u64,
) -> Result<()> {
    // Verify admin authorization
    require_keys_eq!(
        ctx.accounts.admin.key(),
        ctx.accounts.vault_state.admin,
        DonationError::Unauthorized
    );

    // Validate limits
    require!(min_amount > 0, DonationError::InvalidAmount);
    require!(max_amount > min_amount, DonationError::InvalidAmount);

    // Store old values for event
    let old_min = ctx.accounts.vault_state.min_donation_amount;
    let old_max = ctx.accounts.vault_state.max_donation_amount;

    // Update state
    ctx.accounts.vault_state.min_donation_amount = min_amount;
    ctx.accounts.vault_state.max_donation_amount = max_amount;

    // Emit event
    emit!(DonationLimitsUpdatedEvent {
        admin: ctx.accounts.admin.key(),
        old_min_amount: old_min,
        old_max_amount: old_max,
        new_min_amount: min_amount,
        new_max_amount: max_amount,
    });

    msg!(
        "Donation limits updated: min {} -> {}, max {} -> {}",
        old_min, min_amount, old_max, max_amount
    );

    Ok(())
}
```

## Testing Guidelines

### Writing Tests

All new features must include tests:

```typescript
it("Should update donation limits", async () => {
    const newMin = new BN(500_000);  // 0.0005 SOL
    const newMax = new BN(50_000_000_000);  // 50 SOL

    await program.methods
        .updateDonationLimits(newMin, newMax)
        .accounts({
            admin: admin.publicKey,
            vaultState: vaultStatePDA,
        })
        .signers([admin])
        .rpc();

    const vaultState = await program.account.vaultState.fetch(vaultStatePDA);
    assert.equal(vaultState.minDonationAmount.toString(), newMin.toString());
    assert.equal(vaultState.maxDonationAmount.toString(), newMax.toString());
});
```

### Test Coverage

Aim for comprehensive test coverage:
- Happy path scenarios
- Error conditions
- Edge cases
- Authorization checks
- State validation

### Running Tests

```bash
# Run all tests
anchor test

# Run with logs
anchor test -- --nocapture

# Run specific test
anchor test -t "test_name"
```

## Pull Request Process

1. **Update Documentation**
   - Update README.md if needed
   - Update API.md for API changes
   - Update CHANGELOG.md

2. **Ensure Tests Pass**
   - All existing tests pass
   - New tests are added
   - Code coverage is maintained

3. **Code Quality**
   - Run `cargo fmt`
   - Run `cargo clippy`
   - Fix all warnings

4. **PR Description**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## Testing
   Description of testing done

   ## Checklist
   - [ ] Tests pass
   - [ ] Documentation updated
   - [ ] CHANGELOG updated
   ```

5. **Review Process**
   - Wait for code review
   - Address feedback
   - Update as needed
   - Get approval

## Reporting Bugs

### Before Submitting

- Check existing issues
- Verify it's reproducible
- Collect relevant information

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Call function X with parameters Y
2. Observe error Z

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Environment**
- Solana version:
- Anchor version:
- Rust version:

**Additional context**
Any other relevant information.
```

## Suggesting Enhancements

### Enhancement Template

```markdown
**Feature Description**
Clear description of the feature.

**Motivation**
Why is this feature needed?

**Proposed Solution**
How would this work?

**Alternatives Considered**
Other approaches you considered.

**Additional Context**
Any other relevant information.
```

## Commit Message Guidelines

Follow conventional commits:

```
type(scope): subject

body

footer
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

### Examples

```bash
feat: add donation limits configuration

Allow admin to set custom min/max donation amounts.
This provides more flexibility for different use cases.

Closes #123

---

fix: prevent overflow in donation calculation

Use checked arithmetic to prevent overflow when
adding large donation amounts.

Fixes #456

---

docs: update API documentation for new features

Add documentation for update_donation_limits and
emergency_withdraw functions.
```

## Questions?

If you have questions:
- Open an issue for discussion
- Check existing documentation
- Ask in pull request comments

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing! 🎉
