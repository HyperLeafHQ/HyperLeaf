//! SPL Token account. Amount is u64. Escrow ATA owner must be the Store PDA.
//! Mint must be JitoSOL for the principal ATA.

use crate::lockbox::Error;
use crate::jito_mint_bytes;

pub const MINT_OFF: usize = 0;
pub const OWNER_OFF: usize = 32;
pub const AMOUNT_OFF: usize = 64;
pub const MIN_LEN: usize = 72;

pub fn parse(data: &[u8]) -> Result<([u8; 32], [u8; 32], u64), Error> {
    if data.len() < MIN_LEN {
        return Err(Error::Zero);
    }
    let mut mint = [0u8; 32];
    let mut owner = [0u8; 32];
    mint.copy_from_slice(&data[MINT_OFF..MINT_OFF + 32]);
    owner.copy_from_slice(&data[OWNER_OFF..OWNER_OFF + 32]);
    let amount = u64::from_le_bytes(
        data[AMOUNT_OFF..AMOUNT_OFF + 8]
            .try_into()
            .map_err(|_| Error::Zero)?,
    );
    Ok((mint, owner, amount))
}

pub fn encode(mint: [u8; 32], owner: [u8; 32], amount: u64) -> Vec<u8> {
    let mut d = vec![0u8; MIN_LEN];
    d[MINT_OFF..MINT_OFF + 32].copy_from_slice(&mint);
    d[OWNER_OFF..OWNER_OFF + 32].copy_from_slice(&owner);
    d[AMOUNT_OFF..AMOUNT_OFF + 8].copy_from_slice(&amount.to_le_bytes());
    d
}

pub fn require_jito_escrow(data: &[u8], store: &[u8; 32]) -> Result<u64, Error> {
    let (mint, owner, amount) = parse(data)?;
    if mint != jito_mint_bytes() {
        return Err(Error::BadMint);
    }
    if &owner != store {
        return Err(Error::BadPeer);
    }
    Ok(amount)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn escrow_must_be_jito_owned_by_store() {
        let store = [9u8; 32];
        let d = encode(jito_mint_bytes(), store, 5_000_000_000);
        assert_eq!(require_jito_escrow(&d, &store).unwrap(), 5_000_000_000);
        let mut other = store;
        other[0] ^= 1;
        assert_eq!(require_jito_escrow(&d, &other), Err(Error::BadPeer));
        let wrong = encode([1u8; 32], store, 1);
        assert_eq!(require_jito_escrow(&wrong, &store), Err(Error::BadMint));
    }
}
