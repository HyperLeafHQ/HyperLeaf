use crate::*;

/// Per-mint destination registry for permissionless `harvest_other`.
/// Seed: `[b"SideDest", mint]`. Writable only via admin `set_harvest_other_dest`.
#[account]
#[derive(InitSpace)]
pub struct SideDest {
    pub mint: Pubkey,
    /// Owner of the fee ATA (1% protocol fee of side tokens).
    pub fee_owner: Pubkey,
    /// Owner of the rest ATA (99% converter / harvest).
    pub rest_owner: Pubkey,
    pub bump: u8,
}

impl SideDest {
    pub const SIZE: usize = 8 + SideDest::INIT_SPACE;
}
