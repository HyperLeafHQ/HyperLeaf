use crate::*;
use oapp::endpoint::{instructions::QuoteParams, state::EndpointSettings, ENDPOINT_SEED, ID as ENDPOINT_ID};

#[derive(Accounts)]
#[instruction(params: QuoteLockParams)]
pub struct QuoteLock<'info> {
    #[account(seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
    #[account(
        seeds = [PEER_SEED, &store.key().to_bytes(), &params.dst_eid.to_be_bytes()],
        bump = peer.bump
    )]
    pub peer: Account<'info, PeerConfig>,
    #[account(seeds = [ENDPOINT_SEED], bump = endpoint.bump, seeds::program = ENDPOINT_ID)]
    pub endpoint: Account<'info, EndpointSettings>,
}

#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct QuoteLockParams {
    pub dst_eid: u32,
    pub receiver: [u8; 32],
    pub atoms: u128,
    pub evm_to: [u8; 32],
    pub options: Vec<u8>,
    pub pay_in_lz_token: bool,
}

impl QuoteLock<'_> {
    pub fn apply(ctx: &Context<QuoteLock>, params: &QuoteLockParams) -> Result<oapp::endpoint::MessagingFee> {
        require!(
            params.dst_eid == leaf_jito_rate::ix::DEST_EID,
            LeafJitoError::BadEid
        );
        // Quote uses a provisional payload with shares==atoms*SHARE_SCALE for empty box,
        // or a placeholder; actual shares computed at lock time. For fee quoting message
        // size is what matters (96 bytes fixed).
        let message = crate::msg_codec::encode(
            leaf_jito_rate::LISTING_TAG,
            params.evm_to,
            params.atoms.saturating_mul(leaf_jito_rate::SHARE_SCALE),
        )
        .to_vec();
        let quote_params = QuoteParams {
            sender: ctx.accounts.store.key(),
            dst_eid: params.dst_eid,
            receiver: params.receiver,
            message,
            pay_in_lz_token: params.pay_in_lz_token,
            options: ctx
                .accounts
                .peer
                .enforced_options
                .combine_options(&None::<Vec<u8>>, &params.options)?,
        };
        oapp::endpoint_cpi::quote(ENDPOINT_ID, ctx.remaining_accounts, quote_params)
    }
}
