//! SPL StakePool account layout. Read-only. `pool_mint` must be JitoSOL.
//! Offsets from `spl-stake-pool` `StakePool` (account_type + 8 pubkeys + bump).

use crate::lockbox::Error;

pub const POOL_MINT_OFF: usize = 162;
pub const TOTAL_LAMPORTS_OFF: usize = 258;
pub const POOL_SUPPLY_OFF: usize = 266;
pub const MIN_LEN: usize = 274;

pub fn parse_pool(data: &[u8], expected_mint: &[u8; 32]) -> Result<(u64, u64), Error> {
    if data.len() < MIN_LEN {
        return Err(Error::BadRate);
    }
    let mint: [u8; 32] = data[POOL_MINT_OFF..POOL_MINT_OFF + 32]
        .try_into()
        .map_err(|_| Error::BadRate)?;
    if &mint != expected_mint {
        return Err(Error::BadMint);
    }
    let lamports = u64::from_le_bytes(
        data[TOTAL_LAMPORTS_OFF..TOTAL_LAMPORTS_OFF + 8]
            .try_into()
            .map_err(|_| Error::BadRate)?,
    );
    let supply = u64::from_le_bytes(
        data[POOL_SUPPLY_OFF..POOL_SUPPLY_OFF + 8]
            .try_into()
            .map_err(|_| Error::BadRate)?,
    );
    if supply == 0 {
        return Err(Error::BadRate);
    }
    Ok((lamports, supply))
}

pub fn encode_pool(mint: [u8; 32], total_lamports: u64, pool_token_supply: u64) -> Vec<u8> {
    let mut d = vec![0u8; MIN_LEN];
    d[0] = 1; // AccountType::StakePool
    d[POOL_MINT_OFF..POOL_MINT_OFF + 32].copy_from_slice(&mint);
    d[TOTAL_LAMPORTS_OFF..TOTAL_LAMPORTS_OFF + 8].copy_from_slice(&total_lamports.to_le_bytes());
    d[POOL_SUPPLY_OFF..POOL_SUPPLY_OFF + 8].copy_from_slice(&pool_token_supply.to_le_bytes());
    d
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::jito_mint_bytes;

    #[test]
    fn rejects_short_and_wrong_mint() {
        assert_eq!(parse_pool(&[0u8; 10], &jito_mint_bytes()), Err(Error::BadRate));
        let mut other = [0u8; 32];
        other[0] = 7;
        let d = encode_pool(other, 10, 10);
        assert_eq!(parse_pool(&d, &jito_mint_bytes()), Err(Error::BadMint));
    }

    #[test]
    fn reads_lamports_and_supply() {
        let d = encode_pool(jito_mint_bytes(), 1_300_000_000, 1_000_000_000);
        let (l, s) = parse_pool(&d, &jito_mint_bytes()).unwrap();
        assert_eq!(l, 1_300_000_000);
        assert_eq!(s, 1_000_000_000);
    }
}
