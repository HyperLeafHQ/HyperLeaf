//! Bind rate reads to the canonical Jito stake-pool account (address + owner + type + mint).

use crate::errors::{map_rate, LeafJitoError};
use anchor_lang::prelude::*;

/// Jito4APyf642JPZPx3hGc6WWJ8zPKtRbRs4P815Awbb
pub fn jito_pool_pubkey() -> Pubkey {
    Pubkey::new_from_array([
        0x04, 0x8a, 0x3e, 0x08, 0xc3, 0xb4, 0x95, 0xbe, 0x17, 0xf4, 0x54, 0x27, 0xd8, 0x9b, 0xec,
        0x5b, 0x80, 0xc7, 0xe2, 0x69, 0x5c, 0x18, 0x64, 0xd7, 0x67, 0x43, 0xdb, 0x39, 0xbe, 0xd3,
        0x46, 0xd6,
    ])
}

/// SPoo1Ku8WFXoNDMHPsrGSTSG1Y47rzgn41SLUNakuHy
pub fn stake_pool_program_pubkey() -> Pubkey {
    Pubkey::new_from_array([
        0x06, 0x81, 0x4e, 0xd4, 0xca, 0xf6, 0x8a, 0x17, 0x46, 0x72, 0xfd, 0xac, 0x86, 0x03, 0x1a,
        0x63, 0xe8, 0x4e, 0xa1, 0x5e, 0xfa, 0x1d, 0x44, 0xb7, 0x22, 0x93, 0xf6, 0xdb, 0xdb, 0x00,
        0x16, 0x50,
    ])
}

pub fn jito_mint_pubkey() -> Pubkey {
    Pubkey::new_from_array(leaf_jito_rate::jito_mint_bytes())
}

pub fn read_jito_rate(pool: &AccountInfo) -> Result<(u64, u64)> {
    require_keys_eq!(*pool.key, jito_pool_pubkey(), LeafJitoError::BadPoolAccount);
    require_keys_eq!(
        *pool.owner,
        stake_pool_program_pubkey(),
        LeafJitoError::BadPoolAccount
    );
    let data = pool.try_borrow_data()?;
    require!(
        data.len() >= leaf_jito_rate::stake_pool::MIN_LEN,
        LeafJitoError::BadPoolAccount
    );
    require!(data[0] == 1, LeafJitoError::BadPoolAccount);
    let mint = leaf_jito_rate::jito_mint_bytes();
    leaf_jito_rate::stake_pool::parse_pool(&data, &mint).map_err(map_rate)
}

pub fn require_token_account(
    ata: &AccountInfo,
    expected_mint: &Pubkey,
    expected_owner: &Pubkey,
) -> Result<u64> {
    require_keys_eq!(*ata.owner, anchor_spl::token::ID, LeafJitoError::BadTokenAccount);
    let data = ata.try_borrow_data()?;
    let (mint, owner, amount) =
        leaf_jito_rate::token::parse(&data).map_err(|_| error!(LeafJitoError::BadTokenAccount))?;
    require!(mint == expected_mint.to_bytes(), LeafJitoError::BadMint);
    require!(owner == expected_owner.to_bytes(), LeafJitoError::BadTokenAccount);
    Ok(amount)
}

/// Derive associated token address without depending on anchor-spl ATA feature
/// (keeps Cargo.lock compatible with Rust 1.84.1).
pub fn get_associated_token_address(wallet: &Pubkey, mint: &Pubkey) -> Pubkey {
    let ata_program = anchor_lang::solana_program::pubkey!("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");
    Pubkey::find_program_address(
        &[wallet.as_ref(), anchor_spl::token::ID.as_ref(), mint.as_ref()],
        &ata_program,
    )
    .0
}
