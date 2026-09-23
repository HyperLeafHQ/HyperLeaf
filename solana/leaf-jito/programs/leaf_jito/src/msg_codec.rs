use crate::errors::LeafJitoError;
use anchor_lang::prelude::*;

pub fn encode(tag: [u8; 32], to: [u8; 32], shares: u128) -> [u8; 96] {
    leaf_jito_rate::encode_bridge(tag, to, shares)
}

pub fn decode(message: &[u8]) -> Result<([u8; 32], [u8; 32], u128)> {
    require!(message.len() == 96, LeafJitoError::InvalidMessage);
    leaf_jito_rate::decode_bridge(message).ok_or_else(|| error!(LeafJitoError::InvalidMessage))
}
