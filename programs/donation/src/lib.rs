use anchor_lang::prelude::*;
use anchor_lang::system_program::{transfer, Transfer};

declare_id!("DoNaT1on1111111111111111111111111111111111111");

/// Minimum donation amount in lamports (0.001 SOL)
const MIN_DONATION: u64 = 1_000_000;

/// Maximum donation amount in lamports (100 SOL)
const MAX_DONATION: u64 = 100_000_000_000;

/// Default minimum donation amount in lamports (0.001 SOL)
const DEFAULT_MIN_DONATION: u64 = 1_000_000;

/// Default maximum donation amount in lamports (100 SOL)
const DEFAULT_MAX_DONATION: u64 = 100_000_000_000;

/// Donation tier thresholds
const TIER_BRONZE: u64 = 1_000_000;      // 0.001 SOL
const TIER_SILVER: u64 = 100_000_000;    // 0.1 SOL
const TIER_GOLD: u64 = 1_000_000_000;    // 1 SOL
const TIER_PLATINUM: u64 = 10_000_000_000; // 10 SOL

/// Maximum number of top donors to track
const MAX_TOP_DONORS: usize = 100;

/// Minimum rent-exempt balance for vault (5000 lamports)
const MIN_VAULT_BALANCE: u64 = 5000;

/// Default withdrawal fee in basis points (0 = no fee, 100 = 1%)
const DEFAULT_WITHDRAWAL_FEE_BPS: u16 = 0;

/// Maximum withdrawal fee in basis points (1000 = 10%)
const MAX_WITHDRAWAL_FEE_BPS: u16 = 1000;

/// Bonus percentage for platinum donors in basis points (500 = 5%)
const PLATINUM_BONUS_BPS: u16 = 500;

/// Seconds in a day for time calculations
const SECONDS_PER_DAY: i64 = 86400;

/// Seconds in an hour for time calculations
const SECONDS_PER_HOUR: i64 = 3600;

/// Lamports per SOL constant
const LAMPORTS_PER_SOL: u64 = 1_000_000_000;

/// Minimum time between donations (in seconds) - anti-spam
const MIN_DONATION_INTERVAL: i64 = 1; // 1 second

/// Maximum donor name length
const MAX_DONOR_NAME_LENGTH: usize = 32;

/// Default vault name
const DEFAULT_VAULT_NAME: &str = "Donation Vault";

/// Milestone amounts for tracking progress (in lamports)
const MILESTONE_1_SOL: u64 = 1_000_000_000;        // 1 SOL
const MILESTONE_10_SOL: u64 = 10_000_000_000;       // 10 SOL
const MILESTONE_100_SOL: u64 = 100_000_000_000;     // 100 SOL
const MILESTONE_1000_SOL: u64 = 1_000_000_000_000;  // 1000 SOL

#[program]
pub mod donation {
    use super::*;

    /// Initialize a new donation vault
    ///
    /// This function sets up a new donation vault with default configuration.
    /// It should be called only once per vault instance.
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts:
    ///   - `admin`: The signer who will become the vault administrator
    ///   - `vault_state`: The PDA that stores vault configuration and statistics
    ///   - `vault`: The PDA that holds the actual SOL donations
    ///   - `system_program`: Required for account creation
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    ///
    /// # Default Configuration
    /// - Min donation: 0.001 SOL (1,000,000 lamports)
    /// - Max donation: 100 SOL (100,000,000,000 lamports)
    /// - Contract status: Unpaused (accepting donations)
    /// - Initial statistics: All zeros
    ///
    /// # Example
    /// ```ignore
    /// program.methods
    ///   .initialize()
    ///   .accounts({ admin, vaultState, vault, systemProgram })
    ///   .rpc();
    /// ```
    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let vault_state = &mut ctx.accounts.vault_state;
        vault_state.admin = ctx.accounts.admin.key();
        vault_state.total_donated = 0;
        vault_state.donation_count = 0;
        vault_state.is_paused = false;
        vault_state.min_donation_amount = DEFAULT_MIN_DONATION;
        vault_state.max_donation_amount = DEFAULT_MAX_DONATION;
        vault_state.total_withdrawn = 0;
        vault_state.unique_donors = 0;
        vault_state.bump = ctx.bumps.vault_state;

        msg!("Donation vault initialized by admin: {}", ctx.accounts.admin.key());
        msg!("Min donation: {} lamports, Max donation: {} lamports",
            DEFAULT_MIN_DONATION, DEFAULT_MAX_DONATION);

        Ok(())
    }

    /// Process a donation from a user to the vault
    ///
    /// This is the core function for accepting donations. It performs comprehensive
    /// validation, transfers SOL to the vault, updates statistics, tracks donor tiers,
    /// and emits relevant events including tier upgrades and milestones.
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts:
    ///   - `donor`: The signer making the donation
    ///   - `vault_state`: The vault configuration and statistics
    ///   - `vault`: The vault PDA receiving the donation
    ///   - `donor_info`: The donor's statistics PDA (auto-created if needed)
    ///   - `system_program`: Required for transfers
    /// * `amount` - The amount of lamports to donate
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    ///
    /// # Errors
    /// * `DonationError::DonationTooSmall` - If donation is below configured minimum
    /// * `DonationError::DonationTooLarge` - If donation exceeds configured maximum
    /// * `DonationError::ContractPaused` - If donations are paused by admin
    /// * `DonationError::Overflow` - If arithmetic overflow occurs
    ///
    /// # Events Emitted
    /// - `DonationEvent`: Always emitted for every donation
    /// - `TierUpgradeEvent`: Emitted when donor reaches a new tier
    /// - `MilestoneReachedEvent`: Emitted when vault reaches a milestone
    ///
    /// # Features
    /// - Automatic tier calculation (Bronze/Silver/Gold/Platinum)
    /// - Unique donor tracking
    /// - Milestone detection (1, 10, 100, 1000 SOL)
    /// - Timestamp recording for last donation
    ///
    /// # Example
    /// ```ignore
    /// // Donate 0.1 SOL
    /// program.methods
    ///   .donate(new BN(100_000_000))
    ///   .accounts({ donor, vaultState, vault, donorInfo, systemProgram })
    ///   .rpc();
    /// ```
    pub fn donate(ctx: Context<Donate>, amount: u64) -> Result<()> {
        let vault_state = &ctx.accounts.vault_state;

        // Check if contract is paused
        require!(!vault_state.is_paused, DonationError::ContractPaused);

        // Validate donation amount using configurable limits
        require!(
            amount >= vault_state.min_donation_amount,
            DonationError::DonationTooSmall
        );
        require!(
            amount <= vault_state.max_donation_amount,
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

        // Check if this is a new donor
        let is_new_donor = ctx.accounts.donor_info.donation_count == 0;

        // Update vault state
        let vault_state = &mut ctx.accounts.vault_state;
        let previous_total = vault_state.total_donated;

        vault_state.total_donated = vault_state
            .total_donated
            .checked_add(amount)
            .ok_or(DonationError::Overflow)?;
        vault_state.donation_count = vault_state
            .donation_count
            .checked_add(1)
            .ok_or(DonationError::Overflow)?;

        // Increment unique donors counter if this is a new donor
        if is_new_donor {
            vault_state.unique_donors = vault_state
                .unique_donors
                .checked_add(1)
                .ok_or(DonationError::Overflow)?;
        }

        let new_total = vault_state.total_donated;

        // Check if milestone was reached
        if let Some(milestone) = check_milestone_reached(previous_total, new_total) {
            let current_timestamp = Clock::get()?.unix_timestamp;
            emit!(MilestoneReachedEvent {
                milestone_amount: milestone,
                total_donated: new_total,
                triggering_donor: ctx.accounts.donor.key(),
                timestamp: current_timestamp,
            });
            msg!("🎯 Milestone reached: {} lamports ({} SOL)!",
                milestone,
                lamports_to_sol(milestone));
        }

        // Update or initialize donor info
        let donor_info = &mut ctx.accounts.donor_info;
        let old_tier = donor_info.tier;

        donor_info.donor = ctx.accounts.donor.key();
        donor_info.total_donated = donor_info
            .total_donated
            .checked_add(amount)
            .ok_or(DonationError::Overflow)?;
        donor_info.donation_count = donor_info
            .donation_count
            .checked_add(1)
            .ok_or(DonationError::Overflow)?;

        let current_timestamp = Clock::get()?.unix_timestamp;
        donor_info.last_donation_timestamp = current_timestamp;

        let new_tier = calculate_tier(donor_info.total_donated);
        donor_info.tier = new_tier;

        // Emit tier upgrade event if tier changed
        if old_tier != new_tier && !is_new_donor {
            emit!(TierUpgradeEvent {
                donor: ctx.accounts.donor.key(),
                old_tier,
                new_tier,
                total_donated: donor_info.total_donated,
                timestamp: current_timestamp,
            });
            msg!("🎉 Tier upgraded: {:?} -> {:?}", old_tier, new_tier);
        }

        // Emit donation event
        emit!(DonationEvent {
            donor: ctx.accounts.donor.key(),
            amount,
            total_donated: vault_state.total_donated,
            donor_tier: donor_info.tier,
        });

        msg!(
            "Donation received: {} lamports from {} (Tier: {:?}, New donor: {})",
            amount,
            ctx.accounts.donor.key(),
            donor_info.tier,
            is_new_donor
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

        // Update total withdrawn
        let vault_state = &mut ctx.accounts.vault_state;
        vault_state.total_withdrawn = vault_state
            .total_withdrawn
            .checked_add(withdraw_amount)
            .ok_or(DonationError::Overflow)?;

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
    ///
    /// # Errors
    /// * `DonationError::Unauthorized` - If caller is not the current admin
    /// * `DonationError::InvalidAdmin` - If new admin is system program or null
    pub fn update_admin(ctx: Context<UpdateAdmin>, new_admin: Pubkey) -> Result<()> {
        // Verify current admin authorization
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.vault_state.admin,
            DonationError::Unauthorized
        );

        // Validate new admin is not system program or default pubkey
        require!(
            new_admin != anchor_lang::system_program::ID,
            DonationError::InvalidAdmin
        );
        require!(
            new_admin != Pubkey::default(),
            DonationError::InvalidAdmin
        );

        let old_admin = ctx.accounts.vault_state.admin;
        ctx.accounts.vault_state.admin = new_admin;

        emit!(AdminTransferEvent {
            old_admin,
            new_admin,
            timestamp: Clock::get()?.unix_timestamp,
        });

        msg!(
            "Admin transferred from {} to {}",
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

        // Update total withdrawn
        let vault_state = &mut ctx.accounts.vault_state;
        vault_state.total_withdrawn = vault_state
            .total_withdrawn
            .checked_add(amount)
            .ok_or(DonationError::Overflow)?;

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

    /// Update donation limits (admin only)
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    /// * `min_amount` - New minimum donation amount in lamports
    /// * `max_amount` - New maximum donation amount in lamports
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    ///
    /// # Errors
    /// * `DonationError::Unauthorized` - If caller is not the admin
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

        let old_min = ctx.accounts.vault_state.min_donation_amount;
        let old_max = ctx.accounts.vault_state.max_donation_amount;

        ctx.accounts.vault_state.min_donation_amount = min_amount;
        ctx.accounts.vault_state.max_donation_amount = max_amount;

        emit!(DonationLimitsUpdatedEvent {
            admin: ctx.accounts.admin.key(),
            old_min_amount: old_min,
            old_max_amount: old_max,
            new_min_amount: min_amount,
            new_max_amount: max_amount,
        });

        msg!(
            "Donation limits updated: min {} -> {}, max {} -> {}",
            old_min,
            min_amount,
            old_max,
            max_amount
        );

        Ok(())
    }

    /// Emergency withdraw with override (admin only)
    /// This function allows admin to withdraw even if contract is paused
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    /// * `amount` - Amount to withdraw (0 for all funds)
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    pub fn emergency_withdraw(ctx: Context<Withdraw>, amount: u64) -> Result<()> {
        // Verify admin authorization
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.vault_state.admin,
            DonationError::Unauthorized
        );

        let vault = ctx.accounts.vault.to_account_info();
        let balance = vault.lamports();

        require!(balance > 0, DonationError::InsufficientFunds);

        // Calculate rent exempt amount
        let rent = Rent::get()?;
        let rent_exempt_minimum = rent.minimum_balance(vault.data_len());

        let withdraw_amount = if amount == 0 {
            // Withdraw all except rent
            require!(
                balance > rent_exempt_minimum,
                DonationError::InsufficientFunds
            );
            balance - rent_exempt_minimum
        } else {
            // Withdraw specific amount
            require!(amount > 0, DonationError::InvalidAmount);
            require!(
                balance >= amount + rent_exempt_minimum,
                DonationError::InsufficientFunds
            );
            amount
        };

        // Transfer funds
        **vault.try_borrow_mut_lamports()? -= withdraw_amount;
        **ctx.accounts.admin.to_account_info().try_borrow_mut_lamports()? += withdraw_amount;

        // Update total withdrawn
        let vault_state = &mut ctx.accounts.vault_state;
        vault_state.total_withdrawn = vault_state
            .total_withdrawn
            .checked_add(withdraw_amount)
            .ok_or(DonationError::Overflow)?;

        emit!(EmergencyWithdrawEvent {
            admin: ctx.accounts.admin.key(),
            amount: withdraw_amount,
            reason: "Emergency withdrawal executed".to_string(),
        });

        msg!(
            "EMERGENCY WITHDRAWAL: {} lamports to admin {}",
            withdraw_amount,
            ctx.accounts.admin.key()
        );

        Ok(())
    }

    /// Get vault statistics
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    ///
    /// # Returns
    /// * `Result<VaultStatistics>` - Vault statistics
    pub fn get_vault_stats(ctx: Context<GetVaultStats>) -> Result<()> {
        let vault_state = &ctx.accounts.vault_state;
        let vault = ctx.accounts.vault.to_account_info();

        let stats = VaultStatistics {
            admin: vault_state.admin,
            total_donated: vault_state.total_donated,
            total_withdrawn: vault_state.total_withdrawn,
            current_balance: vault.lamports(),
            donation_count: vault_state.donation_count,
            unique_donors: vault_state.unique_donors,
            is_paused: vault_state.is_paused,
            min_donation_amount: vault_state.min_donation_amount,
            max_donation_amount: vault_state.max_donation_amount,
        };

        emit!(VaultStatsEvent {
            stats,
        });

        msg!("Vault Statistics:");
        msg!("  Total donated: {} lamports", vault_state.total_donated);
        msg!("  Total withdrawn: {} lamports", vault_state.total_withdrawn);
        msg!("  Current balance: {} lamports", vault.lamports());
        msg!("  Donations count: {}", vault_state.donation_count);
        msg!("  Unique donors: {}", vault_state.unique_donors);
        msg!("  Is paused: {}", vault_state.is_paused);

        Ok(())
    }

    /// Refund a donation to a donor (admin only)
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    /// * `amount` - Amount to refund in lamports
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    ///
    /// # Errors
    /// * `DonationError::Unauthorized` - If caller is not the admin
    /// * `DonationError::InvalidAmount` - If amount is 0
    /// * `DonationError::RefundExceedsDonation` - If refund exceeds donated amount
    /// * `DonationError::InsufficientFunds` - If vault has insufficient balance
    pub fn refund_donation(ctx: Context<RefundDonation>, amount: u64) -> Result<()> {
        // Verify admin authorization
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.vault_state.admin,
            DonationError::Unauthorized
        );

        require!(amount > 0, DonationError::InvalidAmount);

        let donor_info = &ctx.accounts.donor_info;

        // Ensure refund doesn't exceed what donor has donated
        require!(
            amount <= donor_info.total_donated,
            DonationError::RefundExceedsDonation
        );

        let vault = ctx.accounts.vault.to_account_info();
        let balance = vault.lamports();

        // Calculate rent exempt amount
        let rent = Rent::get()?;
        let rent_exempt_minimum = rent.minimum_balance(vault.data_len());

        require!(
            balance >= amount + rent_exempt_minimum,
            DonationError::InsufficientFunds
        );

        let old_tier = donor_info.tier;

        // Transfer refund from vault to donor
        **vault.try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.donor.to_account_info().try_borrow_mut_lamports()? += amount;

        // Update donor info
        let donor_info = &mut ctx.accounts.donor_info;
        donor_info.total_donated = donor_info
            .total_donated
            .checked_sub(amount)
            .ok_or(DonationError::Overflow)?;

        // Recalculate tier
        let new_tier = calculate_tier(donor_info.total_donated);
        donor_info.tier = new_tier;

        // Log tier downgrade if it occurred
        if old_tier != new_tier {
            msg!("⬇️ Tier downgraded: {:?} -> {:?}", old_tier, new_tier);
        }

        emit!(RefundEvent {
            admin: ctx.accounts.admin.key(),
            donor: ctx.accounts.donor.key(),
            amount,
        });

        msg!(
            "Refund processed: {} lamports ({} SOL) to donor {}",
            amount,
            lamports_to_sol(amount),
            ctx.accounts.donor.key()
        );

        Ok(())
    }

    /// Get donor information
    ///
    /// # Arguments
    /// * `ctx` - The context containing all accounts
    ///
    /// # Returns
    /// * `Result<()>` - Success or error
    pub fn get_donor_info(ctx: Context<GetDonorInfo>) -> Result<()> {
        let donor_info = &ctx.accounts.donor_info;

        emit!(DonorInfoEvent {
            donor: donor_info.donor,
            total_donated: donor_info.total_donated,
            donation_count: donor_info.donation_count,
            last_donation_timestamp: donor_info.last_donation_timestamp,
            tier: donor_info.tier,
        });

        msg!("Donor Information:");
        msg!("  Donor: {}", donor_info.donor);
        msg!("  Total donated: {} lamports ({} SOL)",
            donor_info.total_donated,
            lamports_to_sol(donor_info.total_donated));
        msg!("  Donations count: {}", donor_info.donation_count);
        msg!("  Last donation: {}", donor_info.last_donation_timestamp);
        msg!("  Tier: {:?}", donor_info.tier);

        Ok(())
    }
}

// ========================================
// Helper Functions
// ========================================

/// Helper function to calculate donor tier based on total donations
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

/// Convert lamports to SOL
///
/// # Arguments
/// * `lamports` - Amount in lamports
///
/// # Returns
/// * `f64` - Amount in SOL
pub fn lamports_to_sol(lamports: u64) -> f64 {
    lamports as f64 / 1_000_000_000.0
}

/// Convert SOL to lamports
///
/// # Arguments
/// * `sol` - Amount in SOL
///
/// # Returns
/// * `u64` - Amount in lamports
pub fn sol_to_lamports(sol: f64) -> u64 {
    (sol * 1_000_000_000.0) as u64
}

/// Format tier as string
///
/// # Arguments
/// * `tier` - Donor tier
///
/// # Returns
/// * `&str` - Tier name
pub fn tier_to_string(tier: DonorTier) -> &'static str {
    match tier {
        DonorTier::Bronze => "Bronze",
        DonorTier::Silver => "Silver",
        DonorTier::Gold => "Gold",
        DonorTier::Platinum => "Platinum",
    }
}

/// Get tier emoji representation
///
/// # Arguments
/// * `tier` - Donor tier
///
/// # Returns
/// * `&str` - Tier emoji
pub fn tier_to_emoji(tier: DonorTier) -> &'static str {
    match tier {
        DonorTier::Bronze => "🥉",
        DonorTier::Silver => "🥈",
        DonorTier::Gold => "🥇",
        DonorTier::Platinum => "💎",
    }
}

/// Get tier threshold in lamports
///
/// # Arguments
/// * `tier` - Donor tier
///
/// # Returns
/// * `u64` - Minimum lamports required for tier
pub fn get_tier_threshold(tier: DonorTier) -> u64 {
    match tier {
        DonorTier::Bronze => TIER_BRONZE,
        DonorTier::Silver => TIER_SILVER,
        DonorTier::Gold => TIER_GOLD,
        DonorTier::Platinum => TIER_PLATINUM,
    }
}

/// Get next tier for a donor
///
/// # Arguments
/// * `current_tier` - Current donor tier
///
/// # Returns
/// * `Option<DonorTier>` - Next tier or None if already at max
pub fn get_next_tier(current_tier: DonorTier) -> Option<DonorTier> {
    match current_tier {
        DonorTier::Bronze => Some(DonorTier::Silver),
        DonorTier::Silver => Some(DonorTier::Gold),
        DonorTier::Gold => Some(DonorTier::Platinum),
        DonorTier::Platinum => None,
    }
}

/// Calculate amount needed to reach next tier
///
/// # Arguments
/// * `current_donated` - Current total donated amount
/// * `current_tier` - Current donor tier
///
/// # Returns
/// * `Option<u64>` - Lamports needed for next tier or None if at max
pub fn lamports_to_next_tier(current_donated: u64, current_tier: DonorTier) -> Option<u64> {
    get_next_tier(current_tier).map(|next_tier| {
        let next_threshold = get_tier_threshold(next_tier);
        if current_donated >= next_threshold {
            0
        } else {
            next_threshold - current_donated
        }
    })
}

/// Format timestamp to human readable string (Unix timestamp to days ago)
///
/// # Arguments
/// * `timestamp` - Unix timestamp
/// * `current_time` - Current Unix timestamp
///
/// # Returns
/// * `String` - Human readable time difference
pub fn format_time_ago(timestamp: i64, current_time: i64) -> String {
    let diff = current_time - timestamp;
    let days = diff / 86400;
    let hours = (diff % 86400) / 3600;
    let minutes = (diff % 3600) / 60;

    if days > 0 {
        format!("{} days ago", days)
    } else if hours > 0 {
        format!("{} hours ago", hours)
    } else if minutes > 0 {
        format!("{} minutes ago", minutes)
    } else {
        "Just now".to_string()
    }
}

/// Calculate average donation amount
///
/// # Arguments
/// * `total_donated` - Total amount donated
/// * `donation_count` - Number of donations
///
/// # Returns
/// * `u64` - Average donation amount (0 if no donations)
pub fn calculate_average_donation(total_donated: u64, donation_count: u64) -> u64 {
    if donation_count == 0 {
        0
    } else {
        total_donated / donation_count
    }
}

/// Calculate donation percentage of total
///
/// # Arguments
/// * `donor_amount` - Amount donated by specific donor
/// * `total_amount` - Total amount donated by all donors
///
/// # Returns
/// * `f64` - Percentage (0.0 to 100.0)
pub fn calculate_donation_percentage(donor_amount: u64, total_amount: u64) -> f64 {
    if total_amount == 0 {
        0.0
    } else {
        (donor_amount as f64 / total_amount as f64) * 100.0
    }
}

/// Check if donor is in top percentage
///
/// # Arguments
/// * `donor_amount` - Amount donated by specific donor
/// * `total_amount` - Total amount donated
/// * `percentage` - Top percentage to check (e.g., 10.0 for top 10%)
///
/// # Returns
/// * `bool` - Whether donor is in top percentage
pub fn is_top_donor(donor_amount: u64, total_amount: u64, percentage: f64) -> bool {
    let donor_percentage = calculate_donation_percentage(donor_amount, total_amount);
    donor_percentage >= percentage
}

/// Calculate withdrawal fee
///
/// # Arguments
/// * `amount` - Withdrawal amount
/// * `fee_bps` - Fee in basis points (100 = 1%)
///
/// # Returns
/// * `u64` - Fee amount in lamports
pub fn calculate_fee(amount: u64, fee_bps: u16) -> u64 {
    ((amount as u128 * fee_bps as u128) / 10000) as u64
}

/// Check if a milestone was reached with this donation
///
/// # Arguments
/// * `previous_total` - Total donated before this donation
/// * `new_total` - Total donated after this donation
///
/// # Returns
/// * `Option<u64>` - The milestone amount if reached, None otherwise
pub fn check_milestone_reached(previous_total: u64, new_total: u64) -> Option<u64> {
    let milestones = [
        MILESTONE_1_SOL,
        MILESTONE_10_SOL,
        MILESTONE_100_SOL,
        MILESTONE_1000_SOL,
    ];

    for &milestone in milestones.iter() {
        if previous_total < milestone && new_total >= milestone {
            return Some(milestone);
        }
    }

    None
}

/// Get all milestones as array
///
/// # Returns
/// * `Vec<u64>` - Array of all milestone amounts
pub fn get_all_milestones() -> Vec<u64> {
    vec![
        MILESTONE_1_SOL,
        MILESTONE_10_SOL,
        MILESTONE_100_SOL,
        MILESTONE_1000_SOL,
    ]
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
        mut,
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

#[derive(Accounts)]
pub struct GetVaultStats<'info> {
    /// The vault state account
    #[account(
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,

    /// The vault account
    #[account(
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,
}

#[derive(Accounts)]
pub struct RefundDonation<'info> {
    /// The admin performing the refund
    pub admin: Signer<'info>,

    /// The donor receiving the refund
    /// CHECK: This is safe because we're only transferring lamports to this account
    #[account(mut)]
    pub donor: UncheckedAccount<'info>,

    /// The vault state account
    #[account(
        mut,
        seeds = [b"vault_state"],
        bump = vault_state.bump
    )]
    pub vault_state: Account<'info, VaultState>,

    /// The vault account
    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,

    /// The donor info account
    #[account(
        mut,
        seeds = [b"donor_info", donor.key().as_ref()],
        bump
    )]
    pub donor_info: Account<'info, DonorInfo>,
}

#[derive(Accounts)]
pub struct GetDonorInfo<'info> {
    /// The donor info account to query
    #[account(
        seeds = [b"donor_info", donor_info.donor.as_ref()],
        bump
    )]
    pub donor_info: Account<'info, DonorInfo>,
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
    /// Minimum donation amount in lamports
    pub min_donation_amount: u64,
    /// Maximum donation amount in lamports
    pub max_donation_amount: u64,
    /// Total amount withdrawn in lamports
    pub total_withdrawn: u64,
    /// Number of unique donors
    pub unique_donors: u64,
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

#[event]
pub struct DonationLimitsUpdatedEvent {
    /// The admin's public key
    pub admin: Pubkey,
    /// Old minimum amount
    pub old_min_amount: u64,
    /// Old maximum amount
    pub old_max_amount: u64,
    /// New minimum amount
    pub new_min_amount: u64,
    /// New maximum amount
    pub new_max_amount: u64,
}

#[event]
pub struct EmergencyWithdrawEvent {
    /// The admin's public key
    pub admin: Pubkey,
    /// The amount withdrawn
    pub amount: u64,
    /// Reason for emergency withdrawal
    #[index]
    pub reason: String,
}

#[event]
pub struct VaultStatsEvent {
    /// Vault statistics
    pub stats: VaultStatistics,
}

#[event]
pub struct RefundEvent {
    /// The admin's public key
    pub admin: Pubkey,
    /// The donor's public key
    pub donor: Pubkey,
    /// The amount refunded
    pub amount: u64,
}

#[event]
pub struct DonorInfoEvent {
    /// The donor's public key
    pub donor: Pubkey,
    /// Total amount donated by this donor
    pub total_donated: u64,
    /// Number of donations by this donor
    pub donation_count: u64,
    /// Last donation timestamp
    pub last_donation_timestamp: i64,
    /// Current tier
    pub tier: DonorTier,
}

#[event]
pub struct TierUpgradeEvent {
    /// The donor's public key
    pub donor: Pubkey,
    /// Previous tier
    pub old_tier: DonorTier,
    /// New tier
    pub new_tier: DonorTier,
    /// Total amount donated at upgrade
    pub total_donated: u64,
    /// Timestamp of upgrade
    pub timestamp: i64,
}

#[event]
pub struct AdminTransferEvent {
    /// Previous admin's public key
    pub old_admin: Pubkey,
    /// New admin's public key
    pub new_admin: Pubkey,
    /// Timestamp of transfer
    pub timestamp: i64,
}

#[event]
pub struct MilestoneReachedEvent {
    /// Milestone amount reached
    pub milestone_amount: u64,
    /// Total donated when milestone reached
    pub total_donated: u64,
    /// Donor who triggered the milestone
    pub triggering_donor: Pubkey,
    /// Timestamp when milestone reached
    pub timestamp: i64,
}

// ========================================
// Additional Structures
// ========================================

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct VaultStatistics {
    /// The admin public key
    pub admin: Pubkey,
    /// Total amount donated
    pub total_donated: u64,
    /// Total amount withdrawn
    pub total_withdrawn: u64,
    /// Current vault balance
    pub current_balance: u64,
    /// Number of donations
    pub donation_count: u64,
    /// Number of unique donors
    pub unique_donors: u64,
    /// Whether contract is paused
    pub is_paused: bool,
    /// Minimum donation amount
    pub min_donation_amount: u64,
    /// Maximum donation amount
    pub max_donation_amount: u64,
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

    #[msg("Donor account does not exist.")]
    DonorNotFound,

    #[msg("Cannot refund more than donor has donated.")]
    RefundExceedsDonation,

    #[msg("Vault balance is below minimum required.")]
    VaultBalanceTooLow,

    #[msg("Admin cannot be set to system program or null address.")]
    InvalidAdmin,

    #[msg("Donation limits are invalid. Max must be greater than min.")]
    InvalidLimits,

    #[msg("Timestamp is invalid or in the future.")]
    InvalidTimestamp,

    #[msg("Account already initialized.")]
    AlreadyInitialized,

    #[msg("Operation not allowed for this tier.")]
    TierRestriction,
}
