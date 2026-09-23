use crate::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};
use oapp::{
    endpoint::{
        cpi::accounts::Clear, instructions::ClearParams, ConstructCPIContext, ID as ENDPOINT_ID,
    },
    LzReceiveParams,
};

#[derive(Accounts)]
#[instruction(params: LzReceiveParams)]
pub struct LzReceive<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(mut, seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
    #[account(
        seeds = [PEER_SEED, &store.key().to_bytes(), &params.src_eid.to_be_bytes()],
        bump = peer.bump,
        constraint = params.sender == peer.peer_address @ LeafJitoError::BadPeer
    )]
    pub peer: Account<'info, PeerConfig>,
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
    /// Recipient of unlocked JitoSOL (Solana pubkey from payload).
    /// CHECK: matched to payload `to` after decode.
    #[account(mut)]
    pub recipient_ata: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

impl LzReceive<'_> {
    pub fn apply(ctx: &mut Context<LzReceive>, params: &LzReceiveParams) -> Result<()> {
        // clear() — endpoint auth + GUID replay protection (LZ OApp primitive).
        let seeds: &[&[u8]] = &[STORE_SEED, &[ctx.accounts.store.bump]];
        let accounts_for_clear = &ctx.remaining_accounts[0..Clear::MIN_ACCOUNTS_LEN];
        let _ = oapp::endpoint_cpi::clear(
            ENDPOINT_ID,
            ctx.accounts.store.key(),
            accounts_for_clear,
            seeds,
            ClearParams {
                receiver: ctx.accounts.store.key(),
                src_eid: params.src_eid,
                sender: params.sender,
                nonce: params.nonce,
                guid: params.guid,
                message: params.message.clone(),
            },
        )?;

        let (tag, to, shares) = crate::msg_codec::decode(&params.message)?;
        // `to` must be a Solana pubkey (non-EVM-padded).
        leaf_jito_rate::ix::require_solana_peer(&to).map_err(crate::errors::map_rate)?;
        require_keys_eq!(
            ctx.accounts.recipient_ata.owner,
            Pubkey::new_from_array(to),
            LeafJitoError::BadTokenAccount
        );
        require_keys_eq!(
            ctx.accounts.recipient_ata.mint,
            crate::pool::jito_mint_pubkey(),
            LeafJitoError::BadMint
        );

        let (lamports, supply) =
            crate::pool::read_jito_rate(&ctx.accounts.jito_pool.to_account_info())?;

        let prior_harvest = ctx.accounts.store.harvest_atoms;
        let mut box_ = ctx.accounts.store.lockbox();
        let (atoms, _fee) = box_
            .lz_receive(tag, leaf_jito_rate::LISTING_TAG, shares, lamports, supply)
            .map_err(crate::errors::map_rate)?;
        ctx.accounts.store.apply_lockbox(&box_);
        let fee_now = ctx.accounts.store.harvest_atoms.saturating_sub(prior_harvest);

        let bump = ctx.accounts.store.bump;
        let signer_seeds: &[&[u8]] = &[STORE_SEED, &[bump]];

        if fee_now > 0 {
            let fee_u64: u64 = fee_now
                .try_into()
                .map_err(|_| error!(LeafJitoError::MathOverflow))?;
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.escrow_ata.to_account_info(),
                        to: ctx.accounts.harvest_ata.to_account_info(),
                        authority: ctx.accounts.store.to_account_info(),
                    },
                    &[signer_seeds],
                ),
                fee_u64,
            )?;
        }

        let atoms_u64: u64 = atoms
            .try_into()
            .map_err(|_| error!(LeafJitoError::MathOverflow))?;
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.escrow_ata.to_account_info(),
                    to: ctx.accounts.recipient_ata.to_account_info(),
                    authority: ctx.accounts.store.to_account_info(),
                },
                &[signer_seeds],
            ),
            atoms_u64,
        )?;
        Ok(())
    }
}
