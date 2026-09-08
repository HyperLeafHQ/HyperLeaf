//! On-chain instruction codec. Native program (not Anchor): 1-byte discriminator.
//! `Unlock` is **not** a user instruction. Shares only leave via `LzReceive`
//! after dest `LeafOFT.send` burns hJitoSOL.

use crate::encode_bridge;
use crate::lockbox::{Error, Lockbox};

pub const OP_INIT: u8 = 0;
pub const OP_LOCK: u8 = 1;
pub const OP_HARVEST_RATE: u8 = 2;
pub const OP_HARVEST_OTHER: u8 = 3;
pub const OP_HALT: u8 = 4;
pub const OP_LZ_RECEIVE: u8 = 5;

pub const STORE_SEED: &[u8] = b"Store";
pub const DEST_EID: u32 = 30367;
pub const SRC_EID: u32 = 30168;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Ix {
    Init {
        deposit_cap_atoms: u128,
        dest_peer: [u8; 32],
    },
    Lock {
        atoms: u128,
        evm_to: [u8; 32],
    },
    HarvestRate,
    HarvestOther {
        mint: [u8; 32],
    },
    Halt,
}

pub fn encode(ix: &Ix) -> Vec<u8> {
    match ix {
        Ix::Init {
            deposit_cap_atoms,
            dest_peer,
        } => {
            let mut o = vec![OP_INIT];
            o.extend_from_slice(&deposit_cap_atoms.to_le_bytes());
            o.extend_from_slice(dest_peer);
            o
        }
        Ix::Lock { atoms, evm_to } => {
            let mut o = vec![OP_LOCK];
            o.extend_from_slice(&atoms.to_le_bytes());
            o.extend_from_slice(evm_to);
            o
        }
        Ix::HarvestRate => vec![OP_HARVEST_RATE],
        Ix::HarvestOther { mint } => {
            let mut o = vec![OP_HARVEST_OTHER];
            o.extend_from_slice(mint);
            o
        }
        Ix::Halt => vec![OP_HALT],
    }
}

pub fn decode(data: &[u8]) -> Result<Ix, Error> {
    if data.is_empty() {
        return Err(Error::Zero);
    }
    match data[0] {
        OP_INIT => {
            if data.len() < 1 + 16 + 32 {
                return Err(Error::Zero);
            }
            let cap = u128::from_le_bytes(data[1..17].try_into().unwrap());
            let mut dest_peer = [0u8; 32];
            dest_peer.copy_from_slice(&data[17..49]);
            Ok(Ix::Init {
                deposit_cap_atoms: cap,
                dest_peer,
            })
        }
        OP_LOCK => {
            if data.len() < 1 + 16 + 32 {
                return Err(Error::Zero);
            }
            let atoms = u128::from_le_bytes(data[1..17].try_into().unwrap());
            let mut evm_to = [0u8; 32];
            evm_to.copy_from_slice(&data[17..49]);
            Ok(Ix::Lock { atoms, evm_to })
        }
        OP_HARVEST_RATE => Ok(Ix::HarvestRate),
        OP_HARVEST_OTHER => {
            if data.len() < 33 {
                return Err(Error::Zero);
            }
            let mut mint = [0u8; 32];
            mint.copy_from_slice(&data[1..33]);
            Ok(Ix::HarvestOther { mint })
        }
        OP_HALT => Ok(Ix::Halt),
        OP_LZ_RECEIVE => Err(Error::LzOnly),
        _ => Err(Error::Zero),
    }
}

/// HyperEVM dest OFT is a 20-byte address, left-padded in the Solana peer slot.
pub fn require_evm_peer(peer: &[u8; 32]) -> Result<(), Error> {
    if peer[..12] != [0u8; 12] || peer[12..] == [0u8; 20] {
        return Err(Error::BadPeer);
    }
    Ok(())
}

/// Store PDA (this program's OApp receiver) is 32 bytes, not left-padded.
pub fn require_solana_peer(peer: &[u8; 32]) -> Result<(), Error> {
    if *peer == [0u8; 32] || peer[..12] == [0u8; 12] {
        return Err(Error::BadPeer);
    }
    Ok(())
}

/// Lock + build the 96-byte LZ payload dest `LeafOFT` mints from.
pub fn lock_payload(
    box_: &mut Lockbox,
    tag: [u8; 32],
    evm_to: [u8; 32],
    atoms: u128,
    total_lamports: u64,
    pool_token_supply: u64,
) -> Result<([u8; 96], u128), Error> {
    if evm_to[..12] != [0u8; 12] || evm_to[12..] == [0u8; 20] {
        return Err(Error::BadPeer);
    }
    let (shares, _fee) = box_.lock(atoms, total_lamports, pool_token_supply)?;
    Ok((encode_bridge(tag, evm_to, shares), shares))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{LISTING_TAG, RATE_SCALE};

    #[test]
    fn roundtrip_lock_ix() {
        let mut evm_to = [0u8; 32];
        evm_to[31] = 0xab;
        let raw = encode(&Ix::Lock {
            atoms: 5_000_000_000,
            evm_to,
        });
        assert_eq!(
            decode(&raw).unwrap(),
            Ix::Lock {
                atoms: 5_000_000_000,
                evm_to
            }
        );
    }

    #[test]
    fn lz_receive_not_user_ix() {
        assert_eq!(decode(&[OP_LZ_RECEIVE]), Err(Error::LzOnly));
    }

    #[test]
    fn lock_payload_is_96_and_left_padded_to() {
        let mut b = Lockbox::new(1_000_000_000_000);
        let mut to = [0u8; 32];
        to[31] = 0xef;
        let (buf, shares) = lock_payload(&mut b, LISTING_TAG, to, 1_000_000_000, 1_000_000_000, 1_000_000_000)
            .unwrap();
        assert_eq!(shares, 1_000_000_000_000_000_000);
        assert_eq!(&buf[..32], &LISTING_TAG);
        assert_eq!(buf[63], 0xef);
        assert_eq!(buf.len(), 96);
    }

    #[test]
    fn lock_rejects_solana_pubkey_as_evm_to() {
        let mut b = Lockbox::new(1_000_000_000_000);
        let to = [1u8; 32];
        assert_eq!(
            lock_payload(&mut b, LISTING_TAG, to, 1, 1, 1),
            Err(Error::BadPeer)
        );
        let _ = RATE_SCALE;
    }

    #[test]
    fn evm_peer_must_be_padded() {
        let mut p = [0u8; 32];
        p[31] = 1;
        assert!(require_evm_peer(&p).is_ok());
        p[0] = 1;
        assert_eq!(require_evm_peer(&p), Err(Error::BadPeer));
        assert!(require_solana_peer(&p).is_ok());
    }
}
