use crate::*;
use oapp::{
    common::{compact_accounts_with_alts, AccountMetaRef, AddressLocator, EXECUTION_CONTEXT_VERSION_1},
    endpoint::ID as ENDPOINT_ID,
    lz_receive_types_v2::{get_accounts_for_clear, Instruction, LzReceiveTypesV2Result},
    LzReceiveParams,
};

#[derive(Accounts)]
pub struct LzReceiveTypesV2<'info> {
    #[account(seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
}

impl LzReceiveTypesV2<'_> {
    pub fn apply(
        ctx: &Context<LzReceiveTypesV2>,
        params: &LzReceiveParams,
    ) -> Result<LzReceiveTypesV2Result> {
        let store_key = ctx.accounts.store.key();
        let (peer, _) = Pubkey::find_program_address(
            &[PEER_SEED, store_key.as_ref(), &params.src_eid.to_be_bytes()],
            ctx.program_id,
        );

        // Decode recipient from message for ATA listing.
        let (_tag, to, _shares) = crate::msg_codec::decode(&params.message)?;
        let recipient = Pubkey::new_from_array(to);
        let mint = crate::pool::jito_mint_pubkey();
        let recipient_ata = crate::pool::get_associated_token_address(&recipient, &mint);

        let mut accounts = vec![
            AccountMetaRef {
                pubkey: AddressLocator::Payer,
                is_writable: true,
            },
            AccountMetaRef {
                pubkey: store_key.into(),
                is_writable: true,
            },
            AccountMetaRef {
                pubkey: peer.into(),
                is_writable: false,
            },
            AccountMetaRef {
                pubkey: crate::pool::jito_pool_pubkey().into(),
                is_writable: false,
            },
            AccountMetaRef {
                pubkey: ctx.accounts.store.escrow_ata.into(),
                is_writable: true,
            },
            AccountMetaRef {
                pubkey: ctx.accounts.store.harvest_ata.into(),
                is_writable: true,
            },
            AccountMetaRef {
                pubkey: recipient_ata.into(),
                is_writable: true,
            },
            AccountMetaRef {
                pubkey: anchor_spl::token::ID.into(),
                is_writable: false,
            },
        ];

        let accounts_for_clear = get_accounts_for_clear(
            ENDPOINT_ID,
            &store_key,
            params.src_eid,
            &params.sender,
            params.nonce,
        );
        accounts.extend(accounts_for_clear);

        Ok(LzReceiveTypesV2Result {
            context_version: EXECUTION_CONTEXT_VERSION_1,
            alts: ctx.remaining_accounts.iter().map(|a| a.key()).collect(),
            instructions: vec![Instruction::LzReceive {
                accounts: compact_accounts_with_alts(&ctx.remaining_accounts, accounts)?,
            }],
        })
    }
}
