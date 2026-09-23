use crate::*;

#[derive(Accounts)]
#[instruction(params: SetPeerConfigParams)]
pub struct SetPeerConfig<'info> {
    #[account(mut, address = store.admin @ LeafJitoError::Unauthorized)]
    pub admin: Signer<'info>,
    #[account(
        init_if_needed,
        payer = admin,
        space = PeerConfig::SIZE,
        seeds = [PEER_SEED, &store.key().to_bytes(), &params.remote_eid.to_be_bytes()],
        bump
    )]
    pub peer: Account<'info, PeerConfig>,
    #[account(mut, seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
    pub system_program: Program<'info, System>,
}

#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct SetPeerConfigParams {
    pub remote_eid: u32,
    pub config: PeerConfigParam,
}

#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub enum PeerConfigParam {
    PeerAddress([u8; 32]),
    EnforcedOptions {
        send: Vec<u8>,
        send_and_call: Vec<u8>,
    },
}

impl SetPeerConfig<'_> {
    pub fn apply(ctx: &mut Context<SetPeerConfig>, params: &SetPeerConfigParams) -> Result<()> {
        match params.config.clone() {
            PeerConfigParam::PeerAddress(peer_address) => {
                if params.remote_eid == leaf_jito_rate::ix::DEST_EID {
                    leaf_jito_rate::ix::require_evm_peer(&peer_address)
                        .map_err(crate::errors::map_rate)?;
                    let store = &mut ctx.accounts.store;
                    if store.dest_peer != [0u8; 32] && store.dest_peer != peer_address {
                        return err!(LeafJitoError::PeerFrozen);
                    }
                    store.dest_peer = peer_address;
                }
                ctx.accounts.peer.peer_address = peer_address;
            }
            PeerConfigParam::EnforcedOptions {
                send,
                send_and_call,
            } => {
                oapp::options::assert_type_3(&send)?;
                ctx.accounts.peer.enforced_options.send = send;
                oapp::options::assert_type_3(&send_and_call)?;
                ctx.accounts.peer.enforced_options.send_and_call = send_and_call;
            }
        }
        ctx.accounts.peer.bump = ctx.bumps.peer;
        Ok(())
    }
}
