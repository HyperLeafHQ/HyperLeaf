#![allow(clippy::result_large_err)]

pub mod errors;
pub mod instructions;
pub mod msg_codec;
pub mod pool;
pub mod state;

use anchor_lang::prelude::*;
use instructions::*;
use oapp::{
    endpoint::MessagingFee,
    lz_receive_types_v2::{LzReceiveTypesV2Accounts, LzReceiveTypesV2Result},
    LzReceiveParams,
};
use solana_helper::program_id_from_env;

pub use errors::*;
pub use state::*;

declare_id!(anchor_lang::solana_program::pubkey::Pubkey::new_from_array(
    program_id_from_env!(
        "LEAF_JITO_ID",
        "E7UKM5BCAV5dbjuduDDnZXeQJ7muZ4xLCFd4XCBhzDax"
    )
));

pub const LZ_RECEIVE_TYPES_SEED: &[u8] = b"LzReceiveTypes";
pub const STORE_SEED: &[u8] = b"Store";
pub const PEER_SEED: &[u8] = b"Peer";
pub const SIDE_DEST_SEED: &[u8] = b"SideDest";

#[program]
pub mod leaf_jito {
    use super::*;

    pub fn init_store(mut ctx: Context<InitStore>, params: InitStoreParams) -> Result<()> {
        InitStore::apply(&mut ctx, &params)
    }

    pub fn set_peer_config(
        mut ctx: Context<SetPeerConfig>,
        params: SetPeerConfigParams,
    ) -> Result<()> {
        SetPeerConfig::apply(&mut ctx, &params)
    }

    pub fn halt(mut ctx: Context<Halt>) -> Result<()> {
        Halt::apply(&mut ctx)
    }

    pub fn harvest_rate(mut ctx: Context<HarvestRate>) -> Result<()> {
        HarvestRate::apply(&mut ctx)
    }

    pub fn harvest_other(
        mut ctx: Context<HarvestOther>,
        params: HarvestOtherParams,
    ) -> Result<()> {
        HarvestOther::apply(&mut ctx, &params)
    }

    pub fn set_harvest_other_dest(
        mut ctx: Context<SetHarvestOtherDest>,
        params: SetHarvestOtherDestParams,
    ) -> Result<()> {
        SetHarvestOtherDest::apply(&mut ctx, &params)
    }

    pub fn quote_lock(ctx: Context<QuoteLock>, params: QuoteLockParams) -> Result<MessagingFee> {
        QuoteLock::apply(&ctx, &params)
    }

    pub fn lock(mut ctx: Context<Lock>, params: LockParams) -> Result<()> {
        Lock::apply(&mut ctx, &params)
    }

    pub fn lz_receive(mut ctx: Context<LzReceive>, params: LzReceiveParams) -> Result<()> {
        LzReceive::apply(&mut ctx, &params)
    }

    pub fn lz_receive_types_v2(
        ctx: Context<LzReceiveTypesV2>,
        params: LzReceiveParams,
    ) -> Result<LzReceiveTypesV2Result> {
        LzReceiveTypesV2::apply(&ctx, &params)
    }

    pub fn lz_receive_types_info(
        ctx: Context<LzReceiveTypesInfo>,
        params: LzReceiveParams,
    ) -> Result<(u8, LzReceiveTypesV2Accounts)> {
        LzReceiveTypesInfo::apply(&ctx, &params)
    }
}
