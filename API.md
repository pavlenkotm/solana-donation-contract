# 📚 Solana Donation Contract - API Documentation

Complete API reference for the Solana Donation Contract.

## Table of Contents

- [Program Instructions](#program-instructions)
- [Account Structures](#account-structures)
- [State Structures](#state-structures)
- [Events](#events)
- [Errors](#errors)
- [Helper Functions](#helper-functions)
- [Usage Examples](#usage-examples)

---

## Program Instructions

### 1. initialize

Initialize a new donation vault. Must be called before any other operations.

**Signature:**
```rust
pub fn initialize(ctx: Context<Initialize>) -> Result<()>
```

**Accounts:**
| Name | Type | Description |
|------|------|-------------|
| admin | Signer, mut | The admin who will manage the vault |
| vault_state | Account, init | The vault state PDA (seeds: ["vault_state"]) |
| vault | SystemAccount, mut | The vault PDA (seeds: ["vault"]) |
| system_program | Program | Solana System Program |

**State Changes:**
- Initializes `VaultState` with default values
- Sets admin to caller's public key
- Sets min/max donation limits to defaults
- Sets is_paused to false

**Returns:** `Ok(())` on success

---

### 2. donate

Process a donation from a user to the vault.

**Signature:**
```rust
pub fn donate(ctx: Context<Donate>, amount: u64) -> Result<()>
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| amount | u64 | Amount to donate in lamports |

**Accounts:**
| Name | Type | Description |
|------|------|-------------|
| donor | Signer, mut | The donor making the donation |
| vault_state | Account, mut | The vault state PDA |
| vault | SystemAccount, mut | The vault PDA |
| donor_info | Account, init_if_needed | Donor info PDA (seeds: ["donor_info", donor]) |
| system_program | Program | Solana System Program |

**Validation:**
- Amount must be >= `vault_state.min_donation_amount`
- Amount must be <= `vault_state.max_donation_amount`
- Contract must not be paused (`vault_state.is_paused` == false)

**State Changes:**
- Transfers lamports from donor to vault
- Updates `vault_state.total_donated`
- Increments `vault_state.donation_count`
- Increments `vault_state.unique_donors` (if first-time donor)
- Updates or creates `donor_info` record
- Calculates and assigns donor tier

**Events:** Emits `DonationEvent`

**Returns:** `Ok(())` on success

**Errors:**
- `DonationTooSmall` - Amount below minimum
- `DonationTooLarge` - Amount exceeds maximum
- `ContractPaused` - Donations are paused
- `Overflow` - Arithmetic overflow

---

### 3. withdraw

Withdraw all available funds from the vault (admin only).

**Signature:**
```rust
pub fn withdraw(ctx: Context<Withdraw>) -> Result<()>
```

**Accounts:**
| Name | Type | Description |
|------|------|-------------|
| admin | Signer, mut | The admin withdrawing funds |
| vault_state | Account, mut | The vault state PDA |
| vault | SystemAccount, mut | The vault PDA |

**Authorization:**
- Caller must be the current admin

**State Changes:**
- Transfers all funds (minus rent exemption) from vault to admin
- Updates `vault_state.total_withdrawn`

**Events:** Emits `WithdrawEvent`

**Returns:** `Ok(())` on success

**Errors:**
- `Unauthorized` - Caller is not admin
- `InsufficientFunds` - No funds to withdraw

---

### 4. withdraw_partial

Withdraw a specific amount from the vault (admin only).

**Signature:**
```rust
pub fn withdraw_partial(ctx: Context<Withdraw>, amount: u64) -> Result<()>
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| amount | u64 | Amount to withdraw in lamports |

**Accounts:** Same as `withdraw`

**Validation:**
- Amount must be > 0
- Vault must have sufficient balance (amount + rent exemption)

**State Changes:**
- Transfers specified amount from vault to admin
- Updates `vault_state.total_withdrawn`

**Events:** Emits `WithdrawEvent`

**Returns:** `Ok(())` on success

**Errors:**
- `Unauthorized` - Caller is not admin
- `InvalidAmount` - Amount is 0
- `InsufficientFunds` - Insufficient vault balance

---

### 5. pause

Pause the donation contract to stop accepting donations (admin only).

**Signature:**
```rust
pub fn pause(ctx: Context<UpdateAdmin>) -> Result<()>
```

**Accounts:**
| Name | Type | Description |
|------|------|-------------|
| admin | Signer | The admin pausing the contract |
| vault_state | Account, mut | The vault state PDA |

**Authorization:**
- Caller must be the current admin

**State Changes:**
- Sets `vault_state.is_paused` to true

**Events:** Emits `PauseEvent` with `paused: true`

**Returns:** `Ok(())` on success

**Errors:**
- `Unauthorized` - Caller is not admin

---

### 6. unpause

Unpause the donation contract to resume accepting donations (admin only).

**Signature:**
```rust
pub fn unpause(ctx: Context<UpdateAdmin>) -> Result<()>
```

**Accounts:** Same as `pause`

**Authorization:**
- Caller must be the current admin

**State Changes:**
- Sets `vault_state.is_paused` to false

**Events:** Emits `PauseEvent` with `paused: false`

**Returns:** `Ok(())` on success

**Errors:**
- `Unauthorized` - Caller is not admin

---

### 7. update_admin

Transfer admin rights to a new address.

**Signature:**
```rust
pub fn update_admin(ctx: Context<UpdateAdmin>, new_admin: Pubkey) -> Result<()>
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| new_admin | Pubkey | Public key of the new admin |

**Accounts:** Same as `pause`

**Authorization:**
- Caller must be the current admin

**State Changes:**
- Updates `vault_state.admin` to new admin

**Returns:** `Ok(())` on success

**Errors:**
- `Unauthorized` - Caller is not admin

---

### 8. update_donation_limits

Update the minimum and maximum donation amounts (admin only).

**Signature:**
```rust
pub fn update_donation_limits(
    ctx: Context<UpdateAdmin>,
    min_amount: u64,
    max_amount: u64
) -> Result<()>
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| min_amount | u64 | New minimum donation amount in lamports |
| max_amount | u64 | New maximum donation amount in lamports |

**Accounts:** Same as `pause`

**Authorization:**
- Caller must be the current admin

**Validation:**
- min_amount must be > 0
- max_amount must be > min_amount

**State Changes:**
- Updates `vault_state.min_donation_amount`
- Updates `vault_state.max_donation_amount`

**Events:** Emits `DonationLimitsUpdatedEvent`

**Returns:** `Ok(())` on success

**Errors:**
- `Unauthorized` - Caller is not admin
- `InvalidAmount` - Invalid min/max values

---

### 9. emergency_withdraw

Emergency withdrawal that works even when contract is paused (admin only).

**Signature:**
```rust
pub fn emergency_withdraw(ctx: Context<Withdraw>, amount: u64) -> Result<()>
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| amount | u64 | Amount to withdraw (0 = all available funds) |

**Accounts:** Same as `withdraw`

**Authorization:**
- Caller must be the current admin

**Behavior:**
- If amount == 0: withdraws all funds (minus rent exemption)
- If amount > 0: withdraws specified amount
- Works even when contract is paused

**State Changes:**
- Transfers funds from vault to admin
- Updates `vault_state.total_withdrawn`

**Events:** Emits `EmergencyWithdrawEvent`

**Returns:** `Ok(())` on success

**Errors:**
- `Unauthorized` - Caller is not admin
- `InvalidAmount` - Amount validation failed
- `InsufficientFunds` - Insufficient vault balance

---

### 10. get_vault_stats

Retrieve comprehensive vault statistics.

**Signature:**
```rust
pub fn get_vault_stats(ctx: Context<GetVaultStats>) -> Result<()>
```

**Accounts:**
| Name | Type | Description |
|------|------|-------------|
| vault_state | Account | The vault state PDA |
| vault | SystemAccount | The vault PDA |

**Authorization:** None (public view)

**Events:** Emits `VaultStatsEvent` containing:
- admin
- total_donated
- total_withdrawn
- current_balance
- donation_count
- unique_donors
- is_paused
- min_donation_amount
- max_donation_amount

**Returns:** `Ok(())` on success

---

## Account Structures

### Initialize

```rust
#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    pub admin: Signer<'info>,

    #[account(
        init,
        payer = admin,
        space = 8 + VaultState::INIT_SPACE,
        seeds = [b"vault_state"],
        bump
    )]
    pub vault_state: Account<'info, VaultState>,

    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,

    pub system_program: Program<'info, System>,
}
```

### Donate

```rust
#[derive(Accounts)]
pub struct Donate<'info> {
    #[account(mut)]
    pub donor: Signer<'info>,

    #[account(
        mut,
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,

    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,

    #[account(
        init_if_needed,
        payer = donor,
        space = 8 + DonorInfo::INIT_SPACE,
        seeds = [b"donor_info", donor.key().as_ref()],
        bump
    )]
    pub donor_info: Account<'info, DonorInfo>,

    pub system_program: Program<'info, System>,
}
```

### Withdraw

```rust
#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub admin: Signer<'info>,

    #[account(
        mut,
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,

    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,
}
```

### UpdateAdmin

```rust
#[derive(Accounts)]
pub struct UpdateAdmin<'info> {
    pub admin: Signer<'info>,

    #[account(
        mut,
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,
}
```

### GetVaultStats

```rust
#[derive(Accounts)]
pub struct GetVaultStats<'info> {
    #[account(
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,

    #[account(
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,
}
```

---

## State Structures

### VaultState

Main state account for the donation vault.

```rust
#[account]
#[derive(InitSpace)]
pub struct VaultState {
    pub admin: Pubkey,              // 32 bytes
    pub total_donated: u64,         // 8 bytes
    pub donation_count: u64,        // 8 bytes
    pub is_paused: bool,            // 1 byte
    pub min_donation_amount: u64,   // 8 bytes
    pub max_donation_amount: u64,   // 8 bytes
    pub total_withdrawn: u64,       // 8 bytes
    pub unique_donors: u64,         // 8 bytes
    pub bump: u8,                   // 1 byte
}
// Total: 82 bytes + 8 byte discriminator = 90 bytes
```

### DonorInfo

Tracks individual donor statistics.

```rust
#[account]
#[derive(InitSpace)]
pub struct DonorInfo {
    pub donor: Pubkey,                  // 32 bytes
    pub total_donated: u64,             // 8 bytes
    pub donation_count: u64,            // 8 bytes
    pub last_donation_timestamp: i64,   // 8 bytes
    pub tier: DonorTier,                // 1 byte (enum)
}
// Total: 57 bytes + 8 byte discriminator = 65 bytes
```

### DonorTier

Enum representing donor tiers.

```rust
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, Debug, PartialEq, Eq, InitSpace)]
pub enum DonorTier {
    Bronze,     // >= 0.001 SOL (1_000_000 lamports)
    Silver,     // >= 0.1 SOL (100_000_000 lamports)
    Gold,       // >= 1 SOL (1_000_000_000 lamports)
    Platinum,   // >= 10 SOL (10_000_000_000 lamports)
}
```

### VaultStatistics

Statistics data structure (not stored on-chain, used in events).

```rust
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct VaultStatistics {
    pub admin: Pubkey,
    pub total_donated: u64,
    pub total_withdrawn: u64,
    pub current_balance: u64,
    pub donation_count: u64,
    pub unique_donors: u64,
    pub is_paused: bool,
    pub min_donation_amount: u64,
    pub max_donation_amount: u64,
}
```

---

## Events

### DonationEvent

Emitted when a donation is made.

```rust
#[event]
pub struct DonationEvent {
    pub donor: Pubkey,
    pub amount: u64,
    pub total_donated: u64,
    pub donor_tier: DonorTier,
}
```

### WithdrawEvent

Emitted when funds are withdrawn.

```rust
#[event]
pub struct WithdrawEvent {
    pub admin: Pubkey,
    pub amount: u64,
}
```

### PauseEvent

Emitted when contract is paused or unpaused.

```rust
#[event]
pub struct PauseEvent {
    pub admin: Pubkey,
    pub paused: bool,
}
```

### DonationLimitsUpdatedEvent

Emitted when donation limits are updated.

```rust
#[event]
pub struct DonationLimitsUpdatedEvent {
    pub admin: Pubkey,
    pub old_min_amount: u64,
    pub old_max_amount: u64,
    pub new_min_amount: u64,
    pub new_max_amount: u64,
}
```

### EmergencyWithdrawEvent

Emitted when emergency withdrawal is executed.

```rust
#[event]
pub struct EmergencyWithdrawEvent {
    pub admin: Pubkey,
    pub amount: u64,
    pub reason: String,
}
```

### VaultStatsEvent

Emitted when vault statistics are retrieved.

```rust
#[event]
pub struct VaultStatsEvent {
    pub stats: VaultStatistics,
}
```

---

## Errors

```rust
#[error_code]
pub enum DonationError {
    #[msg("Donation amount is too small. Minimum is configurable.")]
    DonationTooSmall,           // 6000

    #[msg("Donation amount is too large. Maximum is configurable.")]
    DonationTooLarge,           // 6001

    #[msg("Only the admin can perform this action.")]
    Unauthorized,               // 6002

    #[msg("Insufficient funds in the vault.")]
    InsufficientFunds,          // 6003

    #[msg("Arithmetic overflow occurred.")]
    Overflow,                   // 6004

    #[msg("The contract is currently paused. Donations are disabled.")]
    ContractPaused,             // 6005

    #[msg("Invalid amount specified. Amount must be greater than 0.")]
    InvalidAmount,              // 6006
}
```

---

## Helper Functions

### lamports_to_sol

Convert lamports to SOL.

```rust
pub fn lamports_to_sol(lamports: u64) -> f64
```

**Example:**
```rust
let sol = lamports_to_sol(1_000_000_000); // Returns 1.0
```

### sol_to_lamports

Convert SOL to lamports.

```rust
pub fn sol_to_lamports(sol: f64) -> u64
```

**Example:**
```rust
let lamports = sol_to_lamports(0.5); // Returns 500_000_000
```

### tier_to_string

Get tier name as string.

```rust
pub fn tier_to_string(tier: DonorTier) -> &'static str
```

**Returns:**
- "Bronze", "Silver", "Gold", or "Platinum"

### tier_to_emoji

Get tier emoji representation.

```rust
pub fn tier_to_emoji(tier: DonorTier) -> &'static str
```

**Returns:**
- "🥉" (Bronze)
- "🥈" (Silver)
- "🥇" (Gold)
- "💎" (Platinum)

---

## Usage Examples

### Initialize Vault

```typescript
const [vaultStatePDA] = PublicKey.findProgramAddressSync(
    [Buffer.from("vault_state")],
    programId
);

const [vaultPDA] = PublicKey.findProgramAddressSync(
    [Buffer.from("vault")],
    programId
);

await program.methods
    .initialize()
    .accounts({
        admin: admin.publicKey,
        vaultState: vaultStatePDA,
        vault: vaultPDA,
        systemProgram: SystemProgram.programId,
    })
    .signers([admin])
    .rpc();
```

### Make a Donation

```typescript
const [donorInfoPDA] = PublicKey.findProgramAddressSync(
    [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
    programId
);

await program.methods
    .donate(new BN(1_000_000)) // 0.001 SOL
    .accounts({
        donor: donor.publicKey,
        vaultState: vaultStatePDA,
        vault: vaultPDA,
        donorInfo: donorInfoPDA,
        systemProgram: SystemProgram.programId,
    })
    .signers([donor])
    .rpc();
```

### Update Donation Limits

```typescript
await program.methods
    .updateDonationLimits(
        new BN(500_000),      // 0.0005 SOL min
        new BN(50_000_000_000) // 50 SOL max
    )
    .accounts({
        admin: admin.publicKey,
        vaultState: vaultStatePDA,
    })
    .signers([admin])
    .rpc();
```

### Get Vault Statistics

```typescript
const listener = program.addEventListener("VaultStatsEvent", (event) => {
    console.log("Total donated:", event.stats.totalDonated.toString());
    console.log("Total withdrawn:", event.stats.totalWithdrawn.toString());
    console.log("Unique donors:", event.stats.uniqueDonors.toString());
});

await program.methods
    .getVaultStats()
    .accounts({
        vaultState: vaultStatePDA,
        vault: vaultPDA,
    })
    .rpc();

// Remove listener when done
program.removeEventListener(listener);
```

### Emergency Withdraw

```typescript
// Withdraw all funds
await program.methods
    .emergencyWithdraw(new BN(0))
    .accounts({
        admin: admin.publicKey,
        vaultState: vaultStatePDA,
        vault: vaultPDA,
    })
    .signers([admin])
    .rpc();

// Withdraw specific amount
await program.methods
    .emergencyWithdraw(new BN(1_000_000_000)) // 1 SOL
    .accounts({
        admin: admin.publicKey,
        vaultState: vaultStatePDA,
        vault: vaultPDA,
    })
    .signers([admin])
    .rpc();
```

---

## Constants

```rust
/// Minimum donation amount in lamports (0.001 SOL)
const MIN_DONATION: u64 = 1_000_000;

/// Maximum donation amount in lamports (100 SOL)
const MAX_DONATION: u64 = 100_000_000_000;

/// Default minimum donation amount
const DEFAULT_MIN_DONATION: u64 = 1_000_000;

/// Default maximum donation amount
const DEFAULT_MAX_DONATION: u64 = 100_000_000_000;

/// Tier thresholds
const TIER_BRONZE: u64 = 1_000_000;        // 0.001 SOL
const TIER_SILVER: u64 = 100_000_000;      // 0.1 SOL
const TIER_GOLD: u64 = 1_000_000_000;      // 1 SOL
const TIER_PLATINUM: u64 = 10_000_000_000; // 10 SOL

/// Maximum number of top donors to track
const MAX_TOP_DONORS: usize = 100;
```

---

## Security Considerations

1. **Admin-only functions** - All admin functions verify caller is current admin
2. **Overflow protection** - All arithmetic uses checked operations
3. **Rent exemption** - Withdrawals always maintain rent-exempt balance
4. **PDA validation** - All PDAs use seed-based derivation
5. **Pause mechanism** - Emergency stop for security incidents
6. **Configurable limits** - Prevent accidental large donations
7. **Event emission** - All state changes emit events for monitoring

---

## Version

Current API Version: **0.3.0**

For changelog and migration guides, see [CHANGELOG.md](./CHANGELOG.md)
