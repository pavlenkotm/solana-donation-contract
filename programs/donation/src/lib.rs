use anchor_lang::prelude::*;

declare_id!("DoNaT1on1111111111111111111111111111111111111");

#[program]
pub mod donation {
    use super::*;

    pub fn donate(ctx: Context<Donate>, amount: u64) -> Result<()> {
        let from = ctx.accounts.from.to_account_info();
        let to = ctx.accounts.vault.to_account_info();
        **from.try_borrow_mut_lamports()? -= amount;
        **to.try_borrow_mut_lamports()? += amount;
        emit!(DonationEvent {
            donor: *ctx.accounts.from.key,
            amount
        });
        Ok(())
    }

    pub fn withdraw(ctx: Context<Withdraw>) -> Result<()> {
        require_keys_eq!(ctx.accounts.admin.key(), ctx.accounts.vault_owner.key());
        let vault = ctx.accounts.vault.to_account_info();
        let owner = ctx.accounts.vault_owner.to_account_info();
        let balance = vault.lamports();
        **vault.try_borrow_mut_lamports()? -= balance;
        **owner.try_borrow_mut_lamports()? += balance;
        emit!(WithdrawEvent {
            owner: *owner.key,
            amount: balance
        });
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Donate<'info> {
    #[account(mut)]
    pub from: Signer<'info>,
    #[account(mut)]
    pub vault: SystemAccount<'info>,
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub vault_owner: Signer<'info>,
    #[account(mut)]
    pub vault: SystemAccount<'info>,
    pub admin: Signer<'info>,
}

#[event]
pub struct DonationEvent {
    pub donor: Pubkey,
    pub amount: u64,
}

#[event]
pub struct WithdrawEvent {
    pub owner: Pubkey,
    pub amount: u64,
}
