use crate::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

#[derive(Accounts)]
pub struct HarvestRate<'info> {
    #[account(mut, seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
    /// CHECK: identity-bound in pool::read_jito_rate
    pub jito_pool: UncheckedAccount<'info>,
    #[account(
        mut,
        constraint = escrow_ata.key() == store.escrow_ata @ LeafJitoError::BadTokenAccount
    )]
    pub escrow_ata: Account<'info, TokenAccount>,
    #[account(
        mut,
        constraint = harvest_ata.key() == store.harvest_ata @ LeafJitoError::BadTokenAccount
    )]
    pub harvest_ata: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

impl HarvestRate<'_> {
    pub fn apply(ctx: &mut Context<HarvestRate>) -> Result<()> {
        let (lamports, supply) = crate::pool::read_jito_rate(&ctx.accounts.jito_pool.to_account_info())?;
        let mut box_ = ctx.accounts.store.lockbox();
        let fee = box_
            .harvest_rate(lamports, supply)
            .map_err(crate::errors::map_rate)?;
        ctx.accounts.store.apply_lockbox(&box_);

        if fee > 0 {
            let fee_u64: u64 = fee
                .try_into()
                .map_err(|_| error!(LeafJitoError::MathOverflow))?;
            let bump = ctx.accounts.store.bump;
            let seeds: &[&[u8]] = &[STORE_SEED, &[bump]];
            let signer = &[seeds];
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.escrow_ata.to_account_info(),
                        to: ctx.accounts.harvest_ata.to_account_info(),
                        authority: ctx.accounts.store.to_account_info(),
                    },
                    signer,
                ),
                fee_u64,
            )?;
        }
        Ok(())
    }
}
