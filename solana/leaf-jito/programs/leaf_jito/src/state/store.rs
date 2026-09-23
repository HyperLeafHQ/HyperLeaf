use crate::*;

/// Anchor Store PDA. Lockbox math mirrors `leaf_jito_rate::store` (167-byte layout).
/// Extra LZ OApp fields (admin, endpoint_program, ATAs) sit outside that native codec.
#[account]
#[derive(InitSpace)]
pub struct Store {
    pub admin: Pubkey,
    pub bump: u8,
    pub endpoint_program: Pubkey,
    pub dest_eid: u32,
    pub dest_peer: [u8; 32],
    pub listing_tag: [u8; 32],
    pub last_accounted: u128,
    pub last_rate: u128,
    pub total_shares: u128,
    pub deposit_cap_atoms: u128,
    pub escrow_atoms: u128,
    pub harvest_atoms: u128,
    pub halted: bool,
    pub escrow_ata: Pubkey,
    pub harvest_ata: Pubkey,
}

impl Store {
    pub const SIZE: usize = 8 + Store::INIT_SPACE;

    pub fn lockbox(&self) -> leaf_jito_rate::lockbox::Lockbox {
        leaf_jito_rate::lockbox::Lockbox {
            last_accounted: self.last_accounted,
            last_rate: self.last_rate,
            total_shares: self.total_shares,
            deposit_cap_atoms: self.deposit_cap_atoms,
            escrow_atoms: self.escrow_atoms,
            harvest_atoms: self.harvest_atoms,
            halted: self.halted,
        }
    }

    pub fn apply_lockbox(&mut self, b: &leaf_jito_rate::lockbox::Lockbox) {
        self.last_accounted = b.last_accounted;
        self.last_rate = b.last_rate;
        self.total_shares = b.total_shares;
        self.deposit_cap_atoms = b.deposit_cap_atoms;
        self.escrow_atoms = b.escrow_atoms;
        self.harvest_atoms = b.harvest_atoms;
        self.halted = b.halted;
    }

    /// 167-byte native layout for off-chain parity with leaf-jito-rate.
    pub fn lockbox_encode(&self) -> [u8; leaf_jito_rate::store::LEN] {
        leaf_jito_rate::store::Store {
            bump: self.bump,
            dest_eid: self.dest_eid,
            dest_peer: self.dest_peer,
            listing_tag: self.listing_tag,
            box_: self.lockbox(),
        }
        .encode()
    }
}

#[account]
#[derive(InitSpace)]
pub struct LzReceiveTypesAccounts {
    pub store: Pubkey,
    pub alt: Pubkey,
    pub bump: u8,
}

impl LzReceiveTypesAccounts {
    pub const SIZE: usize = 8 + LzReceiveTypesAccounts::INIT_SPACE;
}
