use crate::*;

#[derive(Accounts)]
#[instruction(params: SetHarvestOtherDestParams)]
pub struct SetHarvestOtherDest<'info> {
    #[account(mut, address = store.admin @ LeafJitoError::Unauthorized)]
    pub admin: Signer<'info>,
    #[account(seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
    #[account(
        init_if_needed,
        payer = admin,
        space = SideDest::SIZE,
        seeds = [SIDE_DEST_SEED, params.mint.as_ref()],
        bump
    )]
    pub side_dest: Account<'info, SideDest>,
    pub system_program: Program<'info, System>,
}

#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct SetHarvestOtherDestParams {
    pub mint: Pubkey,
    pub fee_owner: Pubkey,
    pub rest_owner: Pubkey,
}

impl SetHarvestOtherDest<'_> {
    pub fn apply(
        ctx: &mut Context<SetHarvestOtherDest>,
        params: &SetHarvestOtherDestParams,
    ) -> Result<()> {
        require_keys_neq!(params.mint, crate::pool::jito_mint_pubkey(), LeafJitoError::HarvestInner);
        let dest = &mut ctx.accounts.side_dest;
        dest.mint = params.mint;
        dest.fee_owner = params.fee_owner;
        dest.rest_owner = params.rest_owner;
        dest.bump = ctx.bumps.side_dest;
        Ok(())
    }
}
