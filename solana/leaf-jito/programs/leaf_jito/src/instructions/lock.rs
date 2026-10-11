use crate::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};
use oapp::endpoint::{
    instructions::SendParams, state::EndpointSettings, ENDPOINT_SEED, ID as ENDPOINT_ID,
};

#[derive(Accounts)]
#[instruction(params: LockParams)]
pub struct Lock<'info> {
    pub user: Signer<'info>,
    #[account(mut, seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
    #[account(
        seeds = [PEER_SEED, &store.key().to_bytes(), &params.dst_eid.to_be_bytes()],
        bump = peer.bump
    )]
    pub peer: Account<'info, PeerConfig>,
    #[account(seeds = [ENDPOINT_SEED], bump = endpoint.bump, seeds::program = ENDPOINT_ID)]
    pub endpoint: Account<'info, EndpointSettings>,
    /// CHECK: identity-bound in pool::read_jito_rate
    pub jito_pool: UncheckedAccount<'info>,
    #[account(
        mut,
        constraint = user_ata.mint == crate::pool::jito_mint_pubkey() @ LeafJitoError::BadMint,
        constraint = user_ata.owner == user.key() @ LeafJitoError::BadTokenAccount
    )]
    pub user_ata: Account<'info, TokenAccount>,
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

#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct LockParams {
    pub dst_eid: u32,
    pub atoms: u128,
    pub evm_to: [u8; 32],
    pub options: Vec<u8>,
    pub native_fee: u64,
    pub lz_token_fee: u64,
}

impl Lock<'_> {
    pub fn apply(ctx: &mut Context<Lock>, params: &LockParams) -> Result<()> {
        require!(
            params.dst_eid == leaf_jito_rate::ix::DEST_EID,
            LeafJitoError::BadPeer
        );
        // Peer PDA address must match frozen dest_peer when set.
        if ctx.accounts.store.dest_peer != [0u8; 32] {
            require!(
                ctx.accounts.peer.peer_address == ctx.accounts.store.dest_peer,
                LeafJitoError::BadPeer
            );
        }

        let (lamports, supply) =
            crate::pool::read_jito_rate(&ctx.accounts.jito_pool.to_account_info())?;

        let mut box_ = ctx.accounts.store.lockbox();
        let (message, shares) = leaf_jito_rate::ix::lock_payload(
            &mut box_,
            leaf_jito_rate::LISTING_TAG,
            params.evm_to,
            params.atoms,
            lamports,
            supply,
        )
        .map_err(crate::errors::map_rate)?;
        // Fee may have been moved escrow→harvest inside lock(); sync before token moves.
        let fee_moved = ctx.accounts.store.harvest_atoms; // prior
        ctx.accounts.store.apply_lockbox(&box_);
        let fee_now = ctx.accounts.store.harvest_atoms.saturating_sub(fee_moved);

        let atoms_u64: u64 = params
            .atoms
            .try_into()
            .map_err(|_| error!(LeafJitoError::MathOverflow))?;

        // Pull user JitoSOL into escrow.
        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.user_ata.to_account_info(),
                    to: ctx.accounts.escrow_ata.to_account_info(),
                    authority: ctx.accounts.user.to_account_info(),
                },
            ),
            atoms_u64,
        )?;

        // Move any retain fee escrow → harvest.
        if fee_now > 0 {
            let fee_u64: u64 = fee_now
                .try_into()
                .map_err(|_| error!(LeafJitoError::MathOverflow))?;
            let bump = ctx.accounts.store.bump;
            let seeds: &[&[u8]] = &[STORE_SEED, &[bump]];
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.escrow_ata.to_account_info(),
                        to: ctx.accounts.harvest_ata.to_account_info(),
                        authority: ctx.accounts.store.to_account_info(),
                    },
                    &[seeds],
                ),
                fee_u64,
            )?;
        }

        let seeds: &[&[u8]] = &[STORE_SEED, &[ctx.accounts.store.bump]];
        let send_params = SendParams {
            dst_eid: params.dst_eid,
            receiver: ctx.accounts.peer.peer_address,
            message: message.to_vec(),
            options: ctx
                .accounts
                .peer
                .enforced_options
                .combine_options(&None::<Vec<u8>>, &params.options)?,
            native_fee: params.native_fee,
            lz_token_fee: params.lz_token_fee,
        };
        oapp::endpoint_cpi::send(
            ENDPOINT_ID,
            ctx.accounts.store.key(),
            ctx.remaining_accounts,
            seeds,
            send_params,
        )?;

        msg!("leaf_jito lock shares={}", shares);
        Ok(())
    }
}
