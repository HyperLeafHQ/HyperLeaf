use crate::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};
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
    /// Recipient wallet from payload `to` (Solana pubkey). May have no JitoSOL ATA yet.
    /// CHECK: matched to payload `to` after decode.
    pub recipient: UncheckedAccount<'info>,
    /// Canonical JitoSOL ATA for `recipient`; created via CreateIdempotent if missing (OFT pattern).
    /// CHECK: address + mint/owner validated after ensure; may be uninitialized on entry.
    #[account(mut)]
    pub recipient_ata: UncheckedAccount<'info>,
    #[account(address = crate::pool::jito_mint_pubkey() @ LeafJitoError::BadMint)]
    pub jito_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    /// CHECK: must be Associated Token Program
    #[account(address = crate::pool::associated_token_program_id())]
    pub associated_token_program: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
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
        let recipient_key = Pubkey::new_from_array(to);
        require_keys_eq!(
            ctx.accounts.recipient.key(),
            recipient_key,
            LeafJitoError::BadTokenAccount
        );

        let mint = crate::pool::jito_mint_pubkey();
        let expected_ata = crate::pool::get_associated_token_address(&recipient_key, &mint);
        require_keys_eq!(
            ctx.accounts.recipient_ata.key(),
            expected_ata,
            LeafJitoError::BadTokenAccount
        );

        // Mirror LayerZero OFT: create recipient ATA if first-time unlock.
        crate::pool::create_ata_idempotent(
            ctx.accounts.payer.to_account_info(),
            ctx.accounts.recipient_ata.to_account_info(),
            ctx.accounts.recipient.to_account_info(),
            ctx.accounts.jito_mint.to_account_info(),
            ctx.accounts.system_program.to_account_info(),
            ctx.accounts.token_program.to_account_info(),
            ctx.accounts.associated_token_program.to_account_info(),
        )?;

        // Validate ATA mint/owner after ensure.
        let _ = crate::pool::require_token_account(
            &ctx.accounts.recipient_ata.to_account_info(),
            &mint,
            &recipient_key,
        )?;

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
        // silence unused import if any
        Ok(())
    }
}
