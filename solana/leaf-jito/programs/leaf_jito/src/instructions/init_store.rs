use crate::*;
use oapp::endpoint::{instructions::RegisterOAppParams, ID as ENDPOINT_ID};

#[derive(Accounts)]
pub struct InitStore<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    /// CHECK: must equal payer; recorded as admin.
    pub admin: UncheckedAccount<'info>,
    #[account(
        init,
        payer = payer,
        space = Store::SIZE,
        seeds = [STORE_SEED],
        bump
    )]
    pub store: Account<'info, Store>,
    #[account(
        init,
        payer = payer,
        space = LzReceiveTypesAccounts::SIZE,
        seeds = [LZ_RECEIVE_TYPES_SEED, &store.key().to_bytes()],
        bump
    )]
    pub lz_receive_types_accounts: Account<'info, LzReceiveTypesAccounts>,
    /// CHECK: JitoSOL ATA owned by Store.
    pub escrow_ata: UncheckedAccount<'info>,
    /// CHECK: JitoSOL harvest ATA.
    pub harvest_ata: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct InitStoreParams {
    pub deposit_cap_atoms: u128,
    pub dest_peer: [u8; 32],
}

impl InitStore<'_> {
    pub fn apply(ctx: &mut Context<InitStore>, params: &InitStoreParams) -> Result<()> {
        require_keys_eq!(
            ctx.accounts.payer.key(),
            ctx.accounts.admin.key(),
            LeafJitoError::Unauthorized
        );
        leaf_jito_rate::ix::require_evm_peer(&params.dest_peer).map_err(crate::errors::map_rate)?;

        let store_key = ctx.accounts.store.key();
        let mint = crate::pool::jito_mint_pubkey();
        let _ = crate::pool::require_token_account(
            &ctx.accounts.escrow_ata.to_account_info(),
            &mint,
            &store_key,
        )?;
        // Fee recipient ATA: mint=JitoSOL and owner=admin (external treasury, not Store).
        // Wrong owner at init is a permanent fee drain (no update path).
        let harvest_data = ctx.accounts.harvest_ata.try_borrow_data()?;
        let (h_mint, h_owner, _) = leaf_jito_rate::token::parse(&harvest_data)
            .map_err(|_| error!(LeafJitoError::BadTokenAccount))?;
        require!(h_mint == mint.to_bytes(), LeafJitoError::BadMint);
        require!(
            h_owner == ctx.accounts.admin.key().to_bytes(),
            LeafJitoError::BadTokenAccount
        );
        drop(harvest_data);

        let store = &mut ctx.accounts.store;
        store.admin = ctx.accounts.admin.key();
        store.bump = ctx.bumps.store;
        store.endpoint_program = ENDPOINT_ID;
        store.dest_eid = leaf_jito_rate::ix::DEST_EID;
        store.dest_peer = params.dest_peer;
        store.listing_tag = leaf_jito_rate::LISTING_TAG;
        store.apply_lockbox(&leaf_jito_rate::lockbox::Lockbox::new(
            params.deposit_cap_atoms,
        ));
        store.escrow_ata = ctx.accounts.escrow_ata.key();
        store.harvest_ata = ctx.accounts.harvest_ata.key();

        ctx.accounts.lz_receive_types_accounts.store = store_key;
        ctx.accounts.lz_receive_types_accounts.alt = Pubkey::default();
        ctx.accounts.lz_receive_types_accounts.bump = ctx.bumps.lz_receive_types_accounts;

        let seeds: &[&[u8]] = &[STORE_SEED, &[store.bump]];
        let register_params = RegisterOAppParams {
            delegate: store.admin,
        };
        oapp::endpoint_cpi::register_oapp(
            ENDPOINT_ID,
            store_key,
            ctx.remaining_accounts,
            seeds,
            register_params,
        )?;
        Ok(())
    }
}
