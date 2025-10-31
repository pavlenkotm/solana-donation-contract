use anchor_lang::prelude::*;
use anchor_lang::system_program::{transfer, Transfer};

declare_id!("DoNaT1on1111111111111111111111111111111111111");

/// Minimum donation amount in lamports (0.001 SOL)
const MIN_DONATION: u64 = 1_000_000;

/// Maximum donation amount in lamports (100 SOL)
const MAX_DONATION: u64 = 100_000_000_000;

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
    pub fn donate(ctx: Context<Donate>, amount: u64) -> Result<()> {
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

        // Emit donation event
        emit!(DonationEvent {
            donor: ctx.accounts.donor.key(),
            amount,
            total_donated: vault_state.total_donated,
        });

        msg!(
            "Donation received: {} lamports from {}",
            amount,
            ctx.accounts.donor.key()
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
    /// PDA bump seed
    pub bump: u8,
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
    /// Total amount donated so far
    pub total_donated: u64,
}

#[event]
pub struct WithdrawEvent {
    /// The admin's public key
    pub admin: Pubkey,
    /// The amount withdrawn
    pub amount: u64,
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
}
