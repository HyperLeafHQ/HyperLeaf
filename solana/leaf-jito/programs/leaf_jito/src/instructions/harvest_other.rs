use crate::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

#[derive(Accounts)]
#[instruction(params: HarvestOtherParams)]
pub struct HarvestOther<'info> {
    #[account(seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
    /// Registered destinations for this side-token mint (admin-set).
    #[account(
        seeds = [SIDE_DEST_SEED, params.mint.as_ref()],
        bump = side_dest.bump,
        constraint = side_dest.mint == params.mint @ LeafJitoError::BadMint
    )]
    pub side_dest: Account<'info, SideDest>,
    /// Side-token ATA owned by Store (NOT JitoSOL).
    #[account(
        mut,
        constraint = side_ata.owner == store.key() @ LeafJitoError::BadTokenAccount,
        constraint = side_ata.mint == params.mint @ LeafJitoError::BadMint
    )]
    pub side_ata: Account<'info, TokenAccount>,
    /// Destination for 1% protocol fee — must be canonical ATA of registered fee_owner.
    #[account(
        mut,
        constraint = fee_ata.mint == params.mint @ LeafJitoError::BadMint,
        constraint = fee_ata.owner == side_dest.fee_owner @ LeafJitoError::BadTokenAccount,
        constraint = fee_ata.key()
            == crate::pool::get_associated_token_address(&side_dest.fee_owner, &params.mint)
            @ LeafJitoError::BadTokenAccount
    )]
    pub fee_ata: Account<'info, TokenAccount>,
    /// Destination for 99% (converter / harvest) — canonical ATA of registered rest_owner.
    #[account(
        mut,
        constraint = rest_ata.mint == params.mint @ LeafJitoError::BadMint,
        constraint = rest_ata.owner == side_dest.rest_owner @ LeafJitoError::BadTokenAccount,
        constraint = rest_ata.key()
            == crate::pool::get_associated_token_address(&side_dest.rest_owner, &params.mint)
            @ LeafJitoError::BadTokenAccount
    )]
    pub rest_ata: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct HarvestOtherParams {
    /// Mint of the side token (must not be JitoSOL; must have SideDest registered).
    pub mint: Pubkey,
}

impl HarvestOther<'_> {
    pub fn apply(ctx: &mut Context<HarvestOther>, params: &HarvestOtherParams) -> Result<()> {
        let mint_str = params.mint.to_string();
        ctx.accounts
            .store
            .lockbox()
            .harvest_other(&mint_str)
            .map_err(crate::errors::map_rate)?;

        // Defense-in-depth: same owner policy as SideDest constraints (unit-tested in rate crate).
        require!(
            leaf_jito_rate::lockbox::Lockbox::side_dest_policy_ok(
                &ctx.accounts.fee_ata.owner.to_bytes(),
                &ctx.accounts.rest_ata.owner.to_bytes(),
                &ctx.accounts.side_dest.fee_owner.to_bytes(),
                &ctx.accounts.side_dest.rest_owner.to_bytes(),
            ),
            LeafJitoError::BadTokenAccount
        );

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
