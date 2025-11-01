use anchor_lang::prelude::*;
use anchor_lang::system_program::{transfer, Transfer};

declare_id!("DoNaT1on1111111111111111111111111111111111111");

/// Minimum donation amount in lamports (0.001 SOL)
const MIN_DONATION: u64 = 1_000_000;

/// Maximum donation amount in lamports (100 SOL)
const MAX_DONATION: u64 = 100_000_000_000;

/// Donation tier thresholds
const TIER_BRONZE: u64 = 1_000_000;      // 0.001 SOL
const TIER_SILVER: u64 = 100_000_000;    // 0.1 SOL
const TIER_GOLD: u64 = 1_000_000_000;    // 1 SOL
const TIER_PLATINUM: u64 = 10_000_000_000; // 10 SOL

#[program]
pub mod donation {
    use super::*;

    /// Initialize a new donation vault
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let vault_state = &mut ctx.accounts.vault_state;
        vault_state.admin = ctx.accounts.admin.key();
        vault_state.total_donated = 0;
        vault_state.donation_count = 0;
        vault_state.is_paused = false;
        vault_state.bump = ctx.bumps.vault_state;

        msg!("Donation vault initialized by admin: {}", ctx.accounts.admin.key());

        Ok(())
    }

    /// Process a donation from a user to the vault
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    /// * `amount` - The amount of lamports to donate
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    ///
    /// # Errors
    /// * `DonationError::DonationTooSmall` - If donation is below minimum
    /// * `DonationError::DonationTooLarge` - If donation exceeds maximum
    /// * `DonationError::ContractPaused` - If donations are paused
    pub fn donate(ctx: Context<Donate>, amount: u64) -> Result<()> {
        let vault_state = &ctx.accounts.vault_state;

        // Check if contract is paused
        require!(!vault_state.is_paused, DonationError::ContractPaused);

        // Validate donation amount
        require!(
            amount >= MIN_DONATION,
            DonationError::DonationTooSmall
        );
        require!(
            amount <= MAX_DONATION,
            DonationError::DonationTooLarge
        );

        // Transfer lamports from donor to vault using CPI
        let cpi_context = CpiContext::new(
            ctx.accounts.system_program.to_account_info(),
            Transfer {
                from: ctx.accounts.donor.to_account_info(),
                to: ctx.accounts.vault.to_account_info(),
            },
        );
        transfer(cpi_context, amount)?;

        // Update vault state
        let vault_state = &mut ctx.accounts.vault_state;
        vault_state.total_donated = vault_state
            .total_donated
            .checked_add(amount)
            .ok_or(DonationError::Overflow)?;
        vault_state.donation_count = vault_state
            .donation_count
            .checked_add(1)
            .ok_or(DonationError::Overflow)?;

        // Update or initialize donor info
        let donor_info = &mut ctx.accounts.donor_info;
        donor_info.donor = ctx.accounts.donor.key();
        donor_info.total_donated = donor_info
            .total_donated
            .checked_add(amount)
            .ok_or(DonationError::Overflow)?;
        donor_info.donation_count = donor_info
            .donation_count
            .checked_add(1)
            .ok_or(DonationError::Overflow)?;
        donor_info.last_donation_timestamp = Clock::get()?.unix_timestamp;
        donor_info.tier = calculate_tier(donor_info.total_donated);

        // Emit donation event
        emit!(DonationEvent {
            donor: ctx.accounts.donor.key(),
            amount,
            total_donated: vault_state.total_donated,
            donor_tier: donor_info.tier,
        });

        msg!(
            "Donation received: {} lamports from {} (Tier: {:?})",
            amount,
            ctx.accounts.donor.key(),
            donor_info.tier
        );

        Ok(())
    }

    /// Withdraw all funds from the vault (admin only)
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    ///
    /// # Errors
    /// * `DonationError::Unauthorized` - If caller is not the admin
    /// * `DonationError::InsufficientFunds` - If vault has no funds
    pub fn withdraw(ctx: Context<Withdraw>) -> Result<()> {
        // Verify admin authorization
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.vault_state.admin,
            DonationError::Unauthorized
        );

        let vault = ctx.accounts.vault.to_account_info();
        let balance = vault.lamports();

        // Check if there are funds to withdraw
        require!(balance > 0, DonationError::InsufficientFunds);

        // Calculate rent exempt amount to keep in vault
        let rent = Rent::get()?;
        let rent_exempt_minimum = rent.minimum_balance(vault.data_len());

        // Ensure we maintain rent exemption
        require!(
            balance > rent_exempt_minimum,
            DonationError::InsufficientFunds
        );

        let withdraw_amount = balance - rent_exempt_minimum;

        // Transfer funds from vault to admin
        **vault.try_borrow_mut_lamports()? -= withdraw_amount;
        **ctx.accounts.admin.to_account_info().try_borrow_mut_lamports()? += withdraw_amount;

        // Emit withdraw event
        emit!(WithdrawEvent {
            admin: ctx.accounts.admin.key(),
            amount: withdraw_amount,
        });

        msg!(
            "Withdrawal successful: {} lamports to admin {}",
            withdraw_amount,
            ctx.accounts.admin.key()
        );

        Ok(())
    }

    /// Update the admin of the donation vault
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    /// * `new_admin` - The public key of the new admin
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    pub fn update_admin(ctx: Context<UpdateAdmin>, new_admin: Pubkey) -> Result<()> {
        // Verify current admin authorization
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.vault_state.admin,
            DonationError::Unauthorized
        );

        let old_admin = ctx.accounts.vault_state.admin;
        ctx.accounts.vault_state.admin = new_admin;

        msg!(
            "Admin updated from {} to {}",
            old_admin,
            new_admin
        );

        Ok(())
    }

    /// Withdraw a specific amount from the vault (admin only)
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    /// * `amount` - The amount to withdraw in lamports
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    pub fn withdraw_partial(ctx: Context<Withdraw>, amount: u64) -> Result<()> {
        // Verify admin authorization
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.vault_state.admin,
            DonationError::Unauthorized
        );

        let vault = ctx.accounts.vault.to_account_info();
        let balance = vault.lamports();

        // Check if there are sufficient funds
        require!(balance > 0, DonationError::InsufficientFunds);
        require!(amount > 0, DonationError::InvalidAmount);

        // Calculate rent exempt amount to keep in vault
        let rent = Rent::get()?;
        let rent_exempt_minimum = rent.minimum_balance(vault.data_len());

        // Ensure we maintain rent exemption after withdrawal
        require!(
            balance >= amount + rent_exempt_minimum,
            DonationError::InsufficientFunds
        );

        // Transfer funds from vault to admin
        **vault.try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.admin.to_account_info().try_borrow_mut_lamports()? += amount;

        // Emit withdraw event
        emit!(WithdrawEvent {
            admin: ctx.accounts.admin.key(),
            amount,
        });

        msg!(
            "Partial withdrawal successful: {} lamports to admin {}",
            amount,
            ctx.accounts.admin.key()
        );

        Ok(())
    }

    /// Pause the donation contract (admin only)
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    pub fn pause(ctx: Context<UpdateAdmin>) -> Result<()> {
        // Verify admin authorization
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.vault_state.admin,
            DonationError::Unauthorized
        );

        ctx.accounts.vault_state.is_paused = true;

        emit!(PauseEvent {
            admin: ctx.accounts.admin.key(),
            paused: true,
        });

        msg!("Contract paused by admin: {}", ctx.accounts.admin.key());

        Ok(())
    }

    /// Unpause the donation contract (admin only)
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    pub fn unpause(ctx: Context<UpdateAdmin>) -> Result<()> {
        // Verify admin authorization
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.vault_state.admin,
            DonationError::Unauthorized
        );

        ctx.accounts.vault_state.is_paused = false;

        emit!(PauseEvent {
            admin: ctx.accounts.admin.key(),
            paused: false,
        });

        msg!("Contract unpaused by admin: {}", ctx.accounts.admin.key());

        Ok(())
    }
}

/// Helper function to calculate donor tier based on total donations
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

// ========================================
// Account Structures
// ========================================

#[derive(Accounts)]
pub struct Initialize<'info> {
    /// The admin who will manage the vault
    #[account(mut)]
    pub admin: Signer<'info>,

    /// The vault state account (PDA)
    #[account(
        init,
        payer = admin,
        space = 8 + VaultState::INIT_SPACE,
        seeds = [b"vault_state"],
        bump
    )]
    pub vault_state: Account<'info, VaultState>,

    /// The vault account that will hold donations (PDA)
    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Donate<'info> {
    /// The donor making the donation
    #[account(mut)]
    pub donor: Signer<'info>,

    /// The vault state account
    #[account(
        mut,
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,

    /// The vault account receiving donations
    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,

    /// The donor info account (tracks individual donor statistics)
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

#[derive(Accounts)]
pub struct Withdraw<'info> {
    /// The admin withdrawing funds
    #[account(mut)]
    pub admin: Signer<'info>,

    /// The vault state account
    #[account(
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,

    /// The vault account to withdraw from
    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,
}

#[derive(Accounts)]
pub struct UpdateAdmin<'info> {
    /// The current admin
    pub admin: Signer<'info>,

    /// The vault state account
    #[account(
        mut,
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,
}

// ========================================
// State Structures
// ========================================

#[account]
#[derive(InitSpace)]
pub struct VaultState {
    /// The admin public key
    pub admin: Pubkey,
    /// Total amount donated in lamports
    pub total_donated: u64,
    /// Number of donations received
    pub donation_count: u64,
    /// Whether the contract is paused
    pub is_paused: bool,
    /// PDA bump seed
    pub bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct DonorInfo {
    /// The donor's public key
    pub donor: Pubkey,
    /// Total amount donated by this donor
    pub total_donated: u64,
    /// Number of donations made by this donor
    pub donation_count: u64,
    /// Timestamp of last donation
    pub last_donation_timestamp: i64,
    /// Donor tier based on total donations
    pub tier: DonorTier,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, Debug, PartialEq, Eq, InitSpace)]
pub enum DonorTier {
    Bronze,
    Silver,
    Gold,
    Platinum,
}

// ========================================
// Events
// ========================================

#[event]
pub struct DonationEvent {
    /// The donor's public key
    pub donor: Pubkey,
    /// The amount donated
    pub amount: u64,
    /// Total amount donated so far (across all donors)
    pub total_donated: u64,
    /// The donor's tier after this donation
    pub donor_tier: DonorTier,
}

#[event]
pub struct WithdrawEvent {
    /// The admin's public key
    pub admin: Pubkey,
    /// The amount withdrawn
    pub amount: u64,
}

#[event]
pub struct PauseEvent {
    /// The admin's public key
    pub admin: Pubkey,
    /// Whether the contract is paused
    pub paused: bool,
}

// ========================================
// Custom Errors
// ========================================

#[error_code]
pub enum DonationError {
    #[msg("Donation amount is too small. Minimum is 0.001 SOL.")]
    DonationTooSmall,

    #[msg("Donation amount is too large. Maximum is 100 SOL.")]
    DonationTooLarge,

    #[msg("Only the admin can perform this action.")]
    Unauthorized,

    #[msg("Insufficient funds in the vault.")]
    InsufficientFunds,

    #[msg("Arithmetic overflow occurred.")]
    Overflow,

    #[msg("The contract is currently paused. Donations are disabled.")]
    ContractPaused,

    #[msg("Invalid amount specified. Amount must be greater than 0.")]
    InvalidAmount,
}
