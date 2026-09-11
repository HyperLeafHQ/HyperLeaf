//! PDA lockbox state machine. No Solana runtime — `cargo test` is the spec.
//! On-chain program must implement these transitions and nothing else.
//!
//! Cash: `escrow_atoms` is the JitoSOL ATA of the Store. Harvest fee leaves
//! escrow immediately (to the harvest ATA). Unlock pays `atoms`, never the
//! whole ATA. Invariant: `escrow_atoms >= last_accounted`. Extra is donation.

use crate::{atoms_from_shares, book_retain_fee, shares_from_atoms, JITO_MINT, STAKE_POOL_PROGRAM};

/// Jito Interceptor (stake-account deposits). Forbidden CPI.
pub const INTERCEPTOR: &str = "5TAiuAh3YGDbwjEruC1ZpXTJWdNDS7Ur7VeqNNiHMmGV";
/// Jito Vault program. Depositing here is restaking / NCN. Forbidden.
pub const VAULT_PROGRAM: &str = "Vau1t6sLNxnzB7ZDsef8TLbPLfyZMYXH8WTNqUdm9g8";
/// Jito Restaking program. Forbidden.
pub const RESTAKING_PROGRAM: &str = "RestkWeAVL8fRGgzhfeoqFhsqKRchg6aa1XrcH96z4Q";
/// NCN VRTs. Never wrap, never harvest_other.
pub const FRAGSOL_MINT: &str = "FRAGSEthVFL7fdqM8hxfxkfCZzUvmg21cqPJVvC1qdbo";
pub const KYSOL_MINT: &str = "kySo1nETpsZE2NWe5vj2C64mPSciH1SppmHb4XieQ7B";
pub const EZSOL_MINT: &str = "ezSoL6fY1PVdJcJsUpe5CM3xkfmy3zoVCABybm5WtiC";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Lockbox {
    pub last_accounted: u128,
    pub last_rate: u128,
    pub total_shares: u128,
    pub deposit_cap_atoms: u128,
    pub escrow_atoms: u128,
    pub harvest_atoms: u128,
    pub halted: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub enum Error {
    Halted,
    Zero,
    Cap,
    BadRate,
    Insufficient,
    HarvestInner,
    ForbiddenCpi,
    BadMint,
    LzOnly,
    BadPeer,
    WrongListing,
    Underbacked,
}

impl Lockbox {
    pub fn new(deposit_cap_atoms: u128) -> Self {
        Self {
            last_accounted: 0,
            last_rate: 0,
            total_shares: 0,
            deposit_cap_atoms,
            escrow_atoms: 0,
            harvest_atoms: 0,
            halted: false,
        }
    }

    fn require_cash(&self) -> Result<(), Error> {
        if self.escrow_atoms < self.last_accounted {
            return Err(Error::Underbacked);
        }
        Ok(())
    }

    /// Settle 1% before wrap/redeem. Moves fee atoms escrow → harvest ATA.
    /// `pool_mint` must be JitoSOL (caller-checked).
    pub fn harvest_rate(&mut self, total_lamports: u64, pool_token_supply: u64) -> Result<u128, Error> {
        let rate = crate::rate(total_lamports, pool_token_supply).ok_or(Error::BadRate)?;
        if rate == 0 {
            return Err(Error::BadRate);
        }
        if self.last_rate == 0 {
            self.last_rate = rate;
            return Ok(0);
        }
        let (fee, next, nr) = book_retain_fee(self.last_accounted, self.last_rate, rate);
        self.last_accounted = next;
        self.last_rate = nr;
        if fee > 0 {
            if self.escrow_atoms < fee {
                return Err(Error::Underbacked);
            }
            self.escrow_atoms -= fee;
            self.harvest_atoms += fee;
        }
        self.require_cash()?;
        Ok(fee)
    }

    /// Pull `atoms` JitoSOL into the escrow ATA, then mint shares.
    /// Returns (shares, fee_moved_to_harvest).
    pub fn lock(
        &mut self,
        atoms: u128,
        total_lamports: u64,
        pool_token_supply: u64,
    ) -> Result<(u128, u128), Error> {
        if self.halted {
            return Err(Error::Halted);
        }
        if atoms == 0 {
            return Err(Error::Zero);
        }
        let fee = self.harvest_rate(total_lamports, pool_token_supply)?;
        if self.total_shares != 0 && self.last_accounted == 0 {
            return Err(Error::Insufficient);
        }
        if self.last_accounted + atoms > self.deposit_cap_atoms {
            return Err(Error::Cap);
        }
        let shares = if self.total_shares == 0 {
            shares_from_atoms(atoms).ok_or(Error::Zero)?
        } else {
            atoms * self.total_shares / self.last_accounted
        };
        if shares == 0 {
            return Err(Error::Zero);
        }
        self.escrow_atoms += atoms;
        self.last_accounted += atoms;
        self.total_shares += shares;
        self.require_cash()?;
        Ok((shares, fee))
    }

    /// Not a user ix. Pays remaining JitoSOL, never the whole ATA.
    /// Returns (atoms_to_user, fee_moved_to_harvest).
    pub fn unlock(
        &mut self,
        shares: u128,
        total_lamports: u64,
        pool_token_supply: u64,
    ) -> Result<(u128, u128), Error> {
        if shares == 0 || shares > self.total_shares {
            return Err(Error::Insufficient);
        }
        let fee = self.harvest_rate(total_lamports, pool_token_supply)?;
        if self.total_shares != 0 && self.last_accounted == 0 {
            return Err(Error::Insufficient);
        }
        let atoms = atoms_from_shares(shares, self.last_accounted, self.total_shares);
        if atoms == 0 {
            return Err(Error::Zero);
        }
        if self.escrow_atoms < atoms {
            return Err(Error::Underbacked);
        }
        self.escrow_atoms -= atoms;
        self.last_accounted -= atoms;
        self.total_shares -= shares;
        self.require_cash()?;
        Ok((atoms, fee))
    }

    /// Extra JitoSOL in the ATA without lock(). Backing, not yield.
    pub fn donate(&mut self, atoms: u128) {
        self.escrow_atoms += atoms;
    }

    /// Side-token ATA on the PDA (airdrop snapshot). Never JitoSOL.
    /// Whole balance is yield: 1% protocol, 99% stays for converter → WHYPE.
    pub fn harvest_other(&self, mint: &str) -> Result<(), Error> {
        if mint == JITO_MINT || mint == FRAGSOL_MINT || mint == KYSOL_MINT || mint == EZSOL_MINT {
            return Err(Error::HarvestInner);
        }
        Ok(())
    }

    pub fn harvest_other_amount(atoms: u128) -> Result<(u128, u128), Error> {
        if atoms == 0 {
            return Err(Error::Zero);
        }
        let fee = atoms * 100 / 10_000;
        Ok((fee, atoms - fee))
    }

    /// Only path that may reduce `total_shares` on-chain. Executor after dest burn.
    pub fn lz_receive(
        &mut self,
        tag: [u8; 32],
        expected_tag: [u8; 32],
        shares: u128,
        total_lamports: u64,
        pool_token_supply: u64,
    ) -> Result<(u128, u128), Error> {
        if tag != expected_tag || tag == [0u8; 32] {
            return Err(Error::WrongListing);
        }
        self.unlock(shares, total_lamports, pool_token_supply)
    }

    pub fn require_no_cpi(&self, program: &str) -> Result<(), Error> {
        if program == STAKE_POOL_PROGRAM
            || program == INTERCEPTOR
            || program == VAULT_PROGRAM
            || program == RESTAKING_PROGRAM
        {
            return Err(Error::ForbiddenCpi);
        }
        Ok(())
    }

    pub fn halt(&mut self) {
        self.halted = true;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::RATE_SCALE;

    fn pool(rate_x: u128) -> (u64, u64) {
        let supply = 1_000_000_000u64;
        let lamports = ((rate_x * supply as u128) / RATE_SCALE) as u64;
        (lamports, supply)
    }

    #[test]
    fn lock_mints_18dp_shares() {
        let mut b = Lockbox::new(1_000_000_000_000);
        let (l, s) = pool(RATE_SCALE);
        let (shares, fee) = b.lock(5_000_000_000, l, s).unwrap();
        assert_eq!(shares, 5_000_000_000_000_000_000);
        assert_eq!(fee, 0);
        assert_eq!(b.last_accounted, 5_000_000_000);
        assert_eq!(b.escrow_atoms, 5_000_000_000);
    }

    #[test]
    fn harvest_then_unlock_is_less_than_deposit() {
        let mut b = Lockbox::new(1_000_000_000_000);
        let (l0, s) = pool(RATE_SCALE);
        let (shares, _) = b.lock(100_000_000_000, l0, s).unwrap();
        let (l1, _) = pool(RATE_SCALE * 11 / 10);
        let fee = b.harvest_rate(l1, s).unwrap();
        assert_eq!(fee, 90_909_090);
        assert_eq!(b.harvest_atoms, fee);
        assert_eq!(b.escrow_atoms, 100_000_000_000 - fee);
        let (out, fee2) = b.unlock(shares, l1, s).unwrap();
        assert_eq!(fee2, 0);
        assert_eq!(out, 100_000_000_000 - fee);
        assert_eq!(b.total_shares, 0);
        assert_eq!(b.escrow_atoms, 0);
        assert_eq!(b.harvest_atoms, fee);
    }

    #[test]
    fn halt_blocks_lock_not_unlock() {
        let mut b = Lockbox::new(1_000_000_000_000);
        let (l, s) = pool(RATE_SCALE);
        let (shares, _) = b.lock(1_000_000_000, l, s).unwrap();
        b.halt();
        assert_eq!(b.lock(1, l, s), Err(Error::Halted));
        assert!(b.unlock(shares, l, s).is_ok());
    }

    #[test]
    fn cannot_harvest_jitosol_as_side_token() {
        let b = Lockbox::new(1);
        assert_eq!(b.harvest_other(JITO_MINT), Err(Error::HarvestInner));
        assert_eq!(b.harvest_other(FRAGSOL_MINT), Err(Error::HarvestInner));
        assert_eq!(b.harvest_other(KYSOL_MINT), Err(Error::HarvestInner));
        assert_eq!(b.harvest_other(EZSOL_MINT), Err(Error::HarvestInner));
        assert!(b.harvest_other("SomeAirdropMint111111111111111111111111111").is_ok());
    }

    #[test]
    fn restake_cpi_forbidden() {
        let b = Lockbox::new(1);
        assert_eq!(b.require_no_cpi(VAULT_PROGRAM), Err(Error::ForbiddenCpi));
        assert_eq!(b.require_no_cpi(RESTAKING_PROGRAM), Err(Error::ForbiddenCpi));
        assert_eq!(b.require_no_cpi(STAKE_POOL_PROGRAM), Err(Error::ForbiddenCpi));
        assert_eq!(b.require_no_cpi(INTERCEPTOR), Err(Error::ForbiddenCpi));
        assert!(b.require_no_cpi("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA").is_ok());
    }

    #[test]
    fn lz_receive_wrong_tag() {
        let mut b = Lockbox::new(1_000_000_000_000);
        let (l, s) = pool(RATE_SCALE);
        let (shares, _) = b.lock(1_000_000_000, l, s).unwrap();
        assert_eq!(
            b.lz_receive([1u8; 32], crate::LISTING_TAG, shares, l, s),
            Err(Error::WrongListing)
        );
        let (out, _) = b
            .lz_receive(crate::LISTING_TAG, crate::LISTING_TAG, shares, l, s)
            .unwrap();
        assert_eq!(out, 1_000_000_000);
    }

    #[test]
    fn harvest_other_one_percent() {
        let (fee, rest) = Lockbox::harvest_other_amount(10_000).unwrap();
        assert_eq!(fee, 100);
        assert_eq!(rest, 9_900);
    }

    #[test]
    fn donation_atoms_not_in_last_accounted() {
        let mut b = Lockbox::new(1_000_000_000_000);
        let (l, s) = pool(RATE_SCALE);
        b.lock(100_000_000_000, l, s).unwrap();
        b.donate(10_000_000_000);
        let (l1, _) = pool(RATE_SCALE * 11 / 10);
        let fee = b.harvest_rate(l1, s).unwrap();
        assert_eq!(fee, 90_909_090);
        assert_eq!(b.last_accounted, 100_000_000_000 - fee);
        assert_eq!(b.escrow_atoms, 110_000_000_000 - fee);
    }

    #[test]
    fn unlock_never_pays_whole_ata() {
        let mut b = Lockbox::new(1_000_000_000_000);
        let (l, s) = pool(RATE_SCALE);
        let (shares, _) = b.lock(100_000_000_000, l, s).unwrap();
        b.donate(7);
        let (out, _) = b.unlock(shares, l, s).unwrap();
        assert_eq!(out, 100_000_000_000);
        assert_eq!(b.escrow_atoms, 7);
        assert_eq!(b.last_accounted, 0);
    }
}
