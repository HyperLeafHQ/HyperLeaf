use anchor_lang::prelude::*;

#[error_code]
pub enum LeafJitoError {
    #[msg("Invalid message length or contents")]
    InvalidMessage,
    #[msg("Unauthorized")]
    Unauthorized,
    #[msg("Halted")]
    Halted,
    #[msg("Zero amount")]
    Zero,
    #[msg("Deposit cap exceeded")]
    Cap,
    #[msg("Bad rate")]
    BadRate,
    #[msg("Insufficient")]
    Insufficient,
    #[msg("Cannot harvest JitoSOL as side token")]
    HarvestInner,
    #[msg("Forbidden CPI")]
    ForbiddenCpi,
    #[msg("Bad mint")]
    BadMint,
    #[msg("LzReceive only")]
    LzOnly,
    #[msg("Bad peer")]
    BadPeer,
    #[msg("Wrong listing tag")]
    WrongListing,
    #[msg("Underbacked escrow")]
    Underbacked,
    #[msg("Bad Jito stake pool account")]
    BadPoolAccount,
    #[msg("Math overflow")]
    MathOverflow,
    #[msg("Bad token account")]
    BadTokenAccount,
    #[msg("Peer frozen")]
    PeerFrozen,
}

impl From<leaf_jito_rate::lockbox::Error> for LeafJitoError {
    fn from(e: leaf_jito_rate::lockbox::Error) -> Self {
        use leaf_jito_rate::lockbox::Error::*;
        match e {
            Halted => Self::Halted,
            Zero => Self::Zero,
            Cap => Self::Cap,
            BadRate => Self::BadRate,
            Insufficient => Self::Insufficient,
            HarvestInner => Self::HarvestInner,
            ForbiddenCpi => Self::ForbiddenCpi,
            BadMint => Self::BadMint,
            LzOnly => Self::LzOnly,
            BadPeer => Self::BadPeer,
            WrongListing => Self::WrongListing,
            Underbacked => Self::Underbacked,
        }
    }
}

pub fn map_rate(e: leaf_jito_rate::lockbox::Error) -> anchor_lang::error::Error {
    use leaf_jito_rate::lockbox::Error::*;
    match e {
        Halted => error!(LeafJitoError::Halted),
        Zero => error!(LeafJitoError::Zero),
        Cap => error!(LeafJitoError::Cap),
        BadRate => error!(LeafJitoError::BadRate),
        Insufficient => error!(LeafJitoError::Insufficient),
        HarvestInner => error!(LeafJitoError::HarvestInner),
        ForbiddenCpi => error!(LeafJitoError::ForbiddenCpi),
        BadMint => error!(LeafJitoError::BadMint),
        LzOnly => error!(LeafJitoError::LzOnly),
        BadPeer => error!(LeafJitoError::BadPeer),
        WrongListing => error!(LeafJitoError::WrongListing),
        Underbacked => error!(LeafJitoError::Underbacked),
    }
}
