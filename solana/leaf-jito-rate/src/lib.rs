//! Same numbers as `src/lz/LeafJitoRate.sol`. The Solana lockbox CPI must not
//! touch the Jito stake pool — wrap JitoSOL mint only.

pub const YIELD_FEE_BPS: u128 = 100;
pub const BPS: u128 = 10_000;
pub const RATE_SCALE: u128 = 1_000_000_000_000_000_000;
pub const SHARE_SCALE: u128 = 1_000_000_000;

/// Jito stake pool (mainnet).
pub const JITO_POOL: &str = "Jito4APyf642JPZPx3hGc6WWJ8zPKtRbRs4P815Awbb";
/// JitoSOL mint. Wrap this. Never SOL.
pub const JITO_MINT: &str = "J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn";
/// SPL stake pool program. Forbidden as a CPI target.
pub const STAKE_POOL_PROGRAM: &str = "SPoo1Ku8WFXoNDMHPsrGSTSG1Y47rzgn41SLUNakuHy";

pub fn rate(total_lamports: u64, pool_token_supply: u64) -> Option<u128> {
    if pool_token_supply == 0 {
        return None;
    }
    Some((total_lamports as u128) * RATE_SCALE / (pool_token_supply as u128))
}

pub fn shares_from_atoms(atoms: u128) -> Option<u128> {
    atoms.checked_mul(SHARE_SCALE)
}

pub fn atoms_from_shares(shares: u128, last_accounted: u128, total_shares: u128) -> u128 {
    if shares == 0 || total_shares == 0 || last_accounted == 0 {
        return 0;
    }
    shares.saturating_mul(last_accounted) / total_shares
}

pub fn book_retain_fee(last_accounted: u128, last_rate: u128, new_rate: u128) -> (u128, u128, u128) {
    if new_rate == 0 {
        return (0, last_accounted, last_rate);
    }
    if last_rate == 0 || last_accounted == 0 {
        return (0, last_accounted, new_rate);
    }
    if new_rate < last_rate {
        return (0, last_accounted, new_rate);
    }
    if new_rate == last_rate {
        return (0, last_accounted, last_rate);
    }
    let add = last_accounted * (new_rate - last_rate) / new_rate;
    let mut fee = add * YIELD_FEE_BPS / BPS;
    if fee > last_accounted {
        fee = last_accounted;
    }
    (fee, last_accounted - fee, new_rate)
}

/// LZ payload LeafOFT decodes: abi.encode(bytes32 tag, bytes32 to, uint256 amount).
pub fn encode_bridge(tag: [u8; 32], to: [u8; 32], amount: u128) -> [u8; 96] {
    let mut out = [0u8; 96];
    out[..32].copy_from_slice(&tag);
    out[32..64].copy_from_slice(&to);
    let mut amt = [0u8; 32];
    let be = amount.to_be_bytes();
    amt[32 - be.len()..].copy_from_slice(&be);
    out[64..].copy_from_slice(&amt);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn retain_one_percent() {
        let (fee, next, r) = book_retain_fee(100_000_000_000, RATE_SCALE, RATE_SCALE * 11 / 10);
        assert_eq!(fee, 90_909_090);
        assert_eq!(next, 100_000_000_000 - 90_909_090);
        assert_eq!(r, RATE_SCALE * 11 / 10);
    }

    #[test]
    fn slash_no_fee() {
        let (fee, next, r) = book_retain_fee(100, RATE_SCALE * 11 / 10, RATE_SCALE * 105 / 100);
        assert_eq!(fee, 0);
        assert_eq!(next, 100);
        assert_eq!(r, RATE_SCALE * 105 / 100);
    }

    #[test]
    fn payload_96_bytes() {
        let tag = [0x11u8; 32];
        let mut to = [0u8; 32];
        to[31] = 0xef;
        let buf = encode_bridge(tag, to, 1_000_000_000_000_000_000);
        assert_eq!(&buf[..32], &tag);
        assert_eq!(buf[63], 0xef);
        assert_eq!(&buf[64 + 24..], &[0x0d, 0xe0, 0xb6, 0xb3, 0xa7, 0x64, 0x00, 0x00]);
    }
}
