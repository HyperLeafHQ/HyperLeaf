use crate::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

#[derive(Accounts)]
pub struct HarvestOther<'info> {
    #[account(seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
    /// Side-token ATA owned by Store (NOT JitoSOL).
    #[account(mut, constraint = side_ata.owner == store.key() @ LeafJitoError::BadTokenAccount)]
    pub side_ata: Account<'info, TokenAccount>,
    /// Destination for 1% protocol fee of the side token.
    #[account(mut)]
    pub fee_ata: Account<'info, TokenAccount>,
    /// Destination for 99% (converter / harvest).
    #[account(mut)]
    pub rest_ata: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct HarvestOtherParams {
    /// Mint of the side token (must not be JitoSOL).
    pub mint: Pubkey,
}

impl HarvestOther<'_> {
    pub fn apply(ctx: &mut Context<HarvestOther>, params: &HarvestOtherParams) -> Result<()> {
        require_keys_eq!(ctx.accounts.side_ata.mint, params.mint, LeafJitoError::BadMint);
        require_keys_eq!(ctx.accounts.fee_ata.mint, params.mint, LeafJitoError::BadMint);
        require_keys_eq!(ctx.accounts.rest_ata.mint, params.mint, LeafJitoError::BadMint);

        let mint_str = params.mint.to_string();
        ctx.accounts
            .store
            .lockbox()
            .harvest_other(&mint_str)
            .map_err(crate::errors::map_rate)?;

        let atoms = ctx.accounts.side_ata.amount as u128;
        let (fee, rest) =
            leaf_jito_rate::lockbox::Lockbox::harvest_other_amount(atoms).map_err(crate::errors::map_rate)?;
        let fee_u64: u64 = fee
            .try_into()
            .map_err(|_| error!(LeafJitoError::MathOverflow))?;
        let rest_u64: u64 = rest
            .try_into()
            .map_err(|_| error!(LeafJitoError::MathOverflow))?;

        let bump = ctx.accounts.store.bump;
        let seeds: &[&[u8]] = &[STORE_SEED, &[bump]];
        let signer = &[seeds];

        if fee_u64 > 0 {
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.side_ata.to_account_info(),
                        to: ctx.accounts.fee_ata.to_account_info(),
                        authority: ctx.accounts.store.to_account_info(),
                    },
                    signer,
                ),
                fee_u64,
            )?;
        }
        if rest_u64 > 0 {
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.side_ata.to_account_info(),
                        to: ctx.accounts.rest_ata.to_account_info(),
                        authority: ctx.accounts.store.to_account_info(),
                    },
                    signer,
                ),
                rest_u64,
            )?;
        }
        Ok(())
    }
}
