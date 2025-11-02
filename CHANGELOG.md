# Changelog

All notable changes to the Solana Donation Contract will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Advanced Vault Features
- **Configurable Donation Limits**: Admin can now set custom min/max donation amounts
  - `update_donation_limits(min_amount, max_amount)` - New admin function
  - Limits are stored in `VaultState` and validated on each donation
  - Default: min 0.001 SOL, max 100 SOL

#### Enhanced Statistics
- **Unique Donors Tracking**: Automatically counts unique donors
  - New field `unique_donors` in `VaultState`
  - Incremented when a first-time donor makes a donation

- **Total Withdrawn Tracking**: Track all withdrawals made from vault
  - New field `total_withdrawn` in `VaultState`
  - Updated automatically on all withdrawal operations

- **Vault Statistics Function**: Get comprehensive vault statistics
  - `get_vault_stats()` - Returns complete vault statistics
  - Includes: total_donated, total_withdrawn, current_balance, donation_count, unique_donors
  - Emits `VaultStatsEvent` for monitoring

#### Emergency Features
- **Emergency Withdraw**: Critical security feature for admin
  - `emergency_withdraw(amount)` - Withdraw even when contract is paused
  - Pass 0 for full withdrawal, or specific amount for partial
  - Emits `EmergencyWithdrawEvent` with reason tracking

#### Helper Functions & Utilities
- **Conversion Helpers**:
  - `lamports_to_sol(lamports)` - Convert lamports to SOL
  - `sol_to_lamports(sol)` - Convert SOL to lamports

- **Tier Utilities**:
  - `tier_to_string(tier)` - Get tier name as string
  - `tier_to_emoji(tier)` - Get tier emoji representation (🥉🥈🥇💎)

#### New Events
- `DonationLimitsUpdatedEvent` - Emitted when donation limits are changed
- `EmergencyWithdrawEvent` - Emitted on emergency withdrawals with reason
- `VaultStatsEvent` - Emitted when statistics are retrieved

#### New Data Structures
- `VaultStatistics` - Comprehensive statistics structure containing:
  - admin, total_donated, total_withdrawn, current_balance
  - donation_count, unique_donors, is_paused
  - min_donation_amount, max_donation_amount

### Changed

#### VaultState Expansion
- Added `min_donation_amount: u64` - Configurable minimum donation
- Added `max_donation_amount: u64` - Configurable maximum donation
- Added `total_withdrawn: u64` - Total amount withdrawn from vault
- Added `unique_donors: u64` - Count of unique donors

#### Improved Validation
- Donation amount validation now uses configurable limits from `VaultState`
- Enhanced error messages for better debugging
- New donor detection for statistics tracking

#### Enhanced Withdraw Functions
- `withdraw()` - Now tracks total_withdrawn
- `withdraw_partial()` - Now tracks total_withdrawn
- Both functions update VaultState with withdrawal amounts

#### Better Documentation
- Comprehensive inline documentation for all functions
- Detailed parameter descriptions
- Return value documentation
- Error condition documentation
- Helper function documentation with examples

### Security Enhancements
- Emergency withdrawal capability for critical situations
- Configurable limits prevent accidental large donations
- Improved overflow protection with checked arithmetic
- Enhanced event emission for better monitoring and auditing

## [0.2.0] - Previous Version

### Features from Previous Release
- Donor tracking with individual profiles
- 4-tier classification system (Bronze, Silver, Gold, Platinum)
- Pause/unpause mechanism
- Partial withdrawals
- Enhanced events with tier information
- Timestamp tracking for donations
- Comprehensive test suite (21+ tests)
- TypeScript Client SDK

## [0.1.0] - Initial Release

### Initial Features
- Basic donation functionality
- Admin-managed vault
- Simple withdraw mechanism
- PDA-based security
- Event emission

---

## Migration Guide

### Upgrading from v0.2.0 to v0.3.0

#### Breaking Changes
The `VaultState` structure has been expanded with new fields. Existing deployed contracts will need to be redeployed or migrated.

#### New Fields in VaultState
```rust
pub struct VaultState {
    // ... existing fields ...
    pub min_donation_amount: u64,     // NEW
    pub max_donation_amount: u64,     // NEW
    pub total_withdrawn: u64,         // NEW
    pub unique_donors: u64,           // NEW
}
```

#### How to Upgrade
1. Redeploy the contract to get the new VaultState structure
2. Initialize with default limits or custom limits via `update_donation_limits`
3. Update your client code to handle new events
4. Use new helper functions for better UX

#### New Admin Functions
```rust
// Set custom donation limits
program.methods.updateDonationLimits(minAmount, maxAmount)

// Emergency withdrawal
program.methods.emergencyWithdraw(amount)

// Get statistics
program.methods.getVaultStats()
```

---

## Support

For questions or issues, please open an issue on GitHub or consult the documentation.
