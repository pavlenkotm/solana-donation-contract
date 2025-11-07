# Contributing to Web3 Multi-Language Playground

Thank you for your interest in contributing to the Web3 Multi-Language Playground! This document provides guidelines for contributing to this multi-language blockchain development showcase.

## 🎯 Overview

This repository demonstrates professional blockchain development across 12+ programming languages. We welcome contributions in any of these areas:

- New language examples
- Improvements to existing examples
- Documentation enhancements
- Bug fixes
- Test coverage improvements
- CI/CD enhancements

## 🚀 Getting Started

### Prerequisites

Depending on which language you're working with, you'll need:

- **Solidity**: Node.js 18+, Hardhat
- **Rust/Solana**: Rust 1.75+, Solana CLI, Anchor
- **Python**: Python 3.8+
- **Go**: Go 1.21+
- **TypeScript**: Node.js 18+
- **Java**: JDK 11+
- **C++**: GCC/Clang, CMake, OpenSSL
- **Swift**: Xcode 14+
- **Move**: Aptos CLI

### Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/solana-donation-contract.git
cd solana-donation-contract

# Add upstream remote
git remote add upstream https://github.com/pavlenkotm/solana-donation-contract.git
```

## 📝 Contribution Guidelines

### Code Style

Each language follows its ecosystem's standard conventions:

#### Solidity
- Use Solidity 0.8.20+
- Follow [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Include NatSpec comments
- Use OpenZeppelin when applicable

#### Rust/Solana
- Run `cargo fmt` before committing
- Use `cargo clippy` for linting
- Follow [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- Document public functions

#### TypeScript
- Use ESLint and Prettier
- Follow [Airbnb Style Guide](https://github.com/airbnb/javascript)
- Add JSDoc comments for functions
- Maintain type safety

#### Python
- Follow [PEP 8](https://pep8.org/)
- Use type hints
- Add docstrings to functions
- Run `black` for formatting

#### Go
- Run `go fmt` before committing
- Use `golint` for linting
- Follow [Effective Go](https://golang.org/doc/effective_go)
- Add godoc comments

#### Java
- Follow [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- Use meaningful variable names
- Add Javadoc comments

#### C++
- Follow [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/)
- Use modern C++17/20 features
- Add Doxygen comments

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(solidity): add batch transfer function
fix(python): correct balance calculation
docs(typescript): update wallet integration guide
test(rust): add tier system tests
chore(ci): update GitHub Actions workflow
refactor(go): improve signature verification performance
```

### Pull Request Process

1. **Create a Branch**
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make Your Changes**
   - Write code
   - Add tests
   - Update documentation
   - Run tests locally

3. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "feat(language): description of changes"
   ```

4. **Push to Your Fork**
   ```bash
   git push origin feat/your-feature-name
   ```

5. **Create Pull Request**
   - Go to GitHub
   - Click "New Pull Request"
   - Fill out the PR template
   - Link related issues

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] New language example
- [ ] Bug fix
- [ ] Feature addition
- [ ] Documentation update
- [ ] Test improvement

## Language(s) Affected
- [ ] Solidity
- [ ] Rust/Solana
- [ ] Python
- [ ] TypeScript
- [ ] Go
- [ ] Java
- [ ] C++
- [ ] Other: _____

## Testing
- [ ] Tests added/updated
- [ ] All tests passing
- [ ] Manual testing completed

## Documentation
- [ ] README updated
- [ ] Code comments added
- [ ] Examples provided

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] No console logs/debug code
- [ ] Documentation is clear
```

## 🆕 Adding a New Language

To add a new language example:

1. **Create Directory Structure**
   ```bash
   mkdir -p languages/your-language/project-name
   ```

2. **Add Project Files**
   - Main code files
   - Build configuration (package.json, Cargo.toml, etc.)
   - Tests
   - README.md

3. **Write Comprehensive README**
   Include:
   - Overview
   - Features
   - Prerequisites
   - Installation steps
   - Usage examples
   - API documentation
   - Testing instructions
   - License

4. **Add Tests**
   - Unit tests
   - Integration tests (if applicable)
   - Test documentation

5. **Update Main README**
   Add your language to `MULTI_LANG_README.md`

6. **Update CI/CD**
   Add build/test job in `.github/workflows/multi-lang-ci.yml`

### Example: Adding a New Language

```bash
# 1. Create directory
mkdir -p languages/kotlin/smart-wallet

# 2. Add code files
cd languages/kotlin/smart-wallet
touch SmartWallet.kt build.gradle.kts

# 3. Write code and tests
# ... (write your example)

# 4. Create README
cat > README.md << 'EOF'
# 🟣 Kotlin Smart Wallet
Professional Ethereum wallet implementation in Kotlin
...
EOF

# 5. Test locally
./gradlew build test

# 6. Update main README
# Add entry in MULTI_LANG_README.md

# 7. Update CI
# Add kotlin-tests job in .github/workflows/multi-lang-ci.yml

# 8. Commit
git add .
git commit -m "feat(kotlin): add smart wallet example"
```

## 🧪 Testing

### Run Tests

```bash
# Solidity
cd languages/solidity/erc20-token && npm test

# Rust/Solana
anchor test

# Python
cd languages/python/web3-scripts && pytest

# TypeScript
cd languages/typescript/dapp-frontend && npm test

# Go
cd languages/go/rpc-tools && go test -v

# Java
cd languages/java/web3j-integration && mvn test

# C++
cd languages/cpp/crypto-algorithms/build && ctest
```

### Test Coverage

Aim for:
- **Unit tests**: 80%+ coverage
- **Integration tests**: Key workflows covered
- **Edge cases**: Error handling tested

## 📚 Documentation

### README Structure

Each language README should include:

```markdown
# [Language Icon] [Language Name] [Project Name]

Brief description

## ✨ Features
- Feature 1
- Feature 2

## 🛠️ Tech Stack
- Technology 1
- Technology 2

## 📋 Prerequisites
Installation requirements

## 🚀 Installation
Step-by-step setup

## 🔨 Usage
Code examples

## 📖 API Documentation
Function descriptions

## 🧪 Testing
How to run tests

## 📄 License
MIT License
```

### Code Comments

- Add clear comments explaining complex logic
- Document public APIs
- Include usage examples in comments
- Keep comments up-to-date with code changes

## 🐛 Bug Reports

Use GitHub Issues with:

- **Title**: Clear, descriptive title
- **Language**: Which language is affected
- **Description**: What happened vs. what should happen
- **Steps to Reproduce**: Detailed steps
- **Environment**: OS, versions, etc.
- **Code Sample**: Minimal reproduction code

Example:

```markdown
**Title**: [Solidity] ERC20 transfer fails with large amounts

**Language**: Solidity

**Description**:
Token transfers fail when amount exceeds 2^96

**Steps to Reproduce**:
1. Deploy token
2. Mint 2^100 tokens
3. Attempt transfer
4. Transaction reverts

**Environment**:
- Hardhat 2.19.0
- Solidity 0.8.20
- Node.js 18.17

**Code**:
```solidity
await token.transfer(recipient, ethers.parseEther("1e30"));
```
```

## 💡 Feature Requests

Use GitHub Issues with:

- Clear use case
- Benefits to the project
- Proposed implementation (optional)
- Related languages/technologies

## 🤝 Code Review

When reviewing PRs:

- ✅ Check code quality
- ✅ Verify tests pass
- ✅ Review documentation
- ✅ Test locally if possible
- ✅ Provide constructive feedback
- ✅ Approve when ready

## 🏆 Recognition

Contributors will be:
- Listed in project documentation
- Credited in commit history
- Mentioned in release notes
- Added to CONTRIBUTORS.md

## 📞 Communication

- **Issues**: Technical discussions, bugs
- **Pull Requests**: Code review, implementation
- **Discussions**: Ideas, questions, proposals

## 🔒 Security

For security vulnerabilities:
1. **DO NOT** open a public issue
2. Email: security@example.com
3. Include:
   - Description
   - Impact
   - Steps to reproduce
   - Suggested fix (if any)

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Thank You!

Your contributions make this project better for everyone in the Web3 community!

---

**Questions?** Open an issue or discussion on GitHub.

**Need help getting started?** Check out [Good First Issues](https://github.com/pavlenkotm/solana-donation-contract/labels/good%20first%20issue)
