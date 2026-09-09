//! On-chain Store PDA layout. Peer is the HyperEVM dest OFT, left-padded.
//! Frozen after first set (same as LeafOApp.PeerFrozen).

use crate::ix::require_evm_peer;
use crate::lockbox::{Error, Lockbox};
use crate::LISTING_TAG;

pub const VERSION: u8 = 1;
pub const LEN: usize = 167;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Store {
    pub bump: u8,
    pub dest_eid: u32,
    pub dest_peer: [u8; 32],
    pub listing_tag: [u8; 32],
    pub box_: Lockbox,
}

impl Store {
    pub fn init(bump: u8, dest_peer: [u8; 32], deposit_cap_atoms: u128) -> Result<Self, Error> {
        require_evm_peer(&dest_peer)?;
        Ok(Self {
            bump,
            dest_eid: crate::ix::DEST_EID,
            dest_peer,
            listing_tag: LISTING_TAG,
            box_: Lockbox::new(deposit_cap_atoms),
        })
    }

    pub fn set_peer(&mut self, peer: [u8; 32]) -> Result<(), Error> {
        require_evm_peer(&peer)?;
        if self.dest_peer != [0u8; 32] && self.dest_peer != peer {
            return Err(Error::BadPeer);
        }
        self.dest_peer = peer;
        Ok(())
    }

    pub fn encode(&self) -> [u8; LEN] {
        let mut d = [0u8; LEN];
        d[0] = VERSION;
        d[1] = self.bump;
        d[2] = u8::from(self.box_.halted);
        d[3..7].copy_from_slice(&self.dest_eid.to_le_bytes());
        d[7..39].copy_from_slice(&self.dest_peer);
        d[39..71].copy_from_slice(&self.listing_tag);
        write_u128(&mut d, 71, self.box_.last_accounted);
        write_u128(&mut d, 87, self.box_.last_rate);
        write_u128(&mut d, 103, self.box_.total_shares);
        write_u128(&mut d, 119, self.box_.deposit_cap_atoms);
        write_u128(&mut d, 135, self.box_.escrow_atoms);
        write_u128(&mut d, 151, self.box_.harvest_atoms);
        d
    }

    pub fn decode(d: &[u8]) -> Result<Self, Error> {
        if d.len() < LEN || d[0] != VERSION {
            return Err(Error::Zero);
        }
        let mut dest_peer = [0u8; 32];
        let mut listing_tag = [0u8; 32];
        dest_peer.copy_from_slice(&d[7..39]);
        listing_tag.copy_from_slice(&d[39..71]);
        if listing_tag != LISTING_TAG {
            return Err(Error::WrongListing);
        }
        let mut box_ = Lockbox::new(read_u128(d, 119));
        box_.halted = d[2] != 0;
        box_.last_accounted = read_u128(d, 71);
        box_.last_rate = read_u128(d, 87);
        box_.total_shares = read_u128(d, 103);
        box_.escrow_atoms = read_u128(d, 135);
        box_.harvest_atoms = read_u128(d, 151);
        Ok(Self {
            bump: d[1],
            dest_eid: u32::from_le_bytes(d[3..7].try_into().unwrap()),
            dest_peer,
            listing_tag,
            box_,
        })
    }
}

fn write_u128(d: &mut [u8], off: usize, v: u128) {
    d[off..off + 16].copy_from_slice(&v.to_le_bytes());
}

fn read_u128(d: &[u8], off: usize) -> u128 {
    u128::from_le_bytes(d[off..off + 16].try_into().unwrap())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_and_peer_freeze() {
        let mut peer = [0u8; 32];
        peer[31] = 0xaa;
        let mut s = Store::init(255, peer, 10_000_000_000).unwrap();
        assert_eq!(s.set_peer(peer), Ok(()));
        let mut other = peer;
        other[31] = 0xbb;
        assert_eq!(s.set_peer(other), Err(Error::BadPeer));
        let raw = s.encode();
        let back = Store::decode(&raw).unwrap();
        assert_eq!(back.dest_peer, peer);
        assert_eq!(back.box_.deposit_cap_atoms, 10_000_000_000);
        assert_eq!(back.listing_tag, LISTING_TAG);
    }

    #[test]
    fn init_rejects_solana_shaped_dest_peer() {
        assert!(Store::init(1, [1u8; 32], 1).is_err());
    }
}
