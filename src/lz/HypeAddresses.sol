// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Canonical HYPE representations Hyperleaf will swap into / pay out.
/// @dev Fake ticker-HYPE (especially BSC) is never a harvest target.
library HypeAddresses {
    /// @dev HyperEVM wrapped native HYPE (WETH-style). Users claim this.
    address internal constant WHYPE = 0x5555555555555555555555555555555555555555;

    /// @dev Wormhole NTT HYPE on Base. Aerodrome HYPE/WETH. Not cbHYPE.
    address internal constant WORMHOLE_HYPE_BASE = 0x15D0e0c55a3E7eE67152aD7E89acf164253Ff68d;

    /// @dev Coinbase-custodied cbHYPE on Base — too thin, do not harvest into.
    address internal constant CBHYPE_BASE = 0xB200000000000000000000451d033a5000cb479e;

    /// @dev Circle native USDC on BSC (harvest hop, not a HYPE stand-in).
    address internal constant USDC_BSC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    /// @dev QUID on Base. hxSQUID side-yield; never pull xSQUID.
    address internal constant QUID_BASE = 0x1a44233FAe8D50F1AeB3a5d58dd426ff4814Cb53;

    /// @dev Virtuals Protocol Stake (Base). hVIRTUALMAX Auto Max-lock.
    address internal constant VIRTUALS_STAKE_BASE = 0x60a203ddcDE45fbfb325bdeEA93824B5726b4dF8;

    /// @dev BLUAI 4-year stake (BSC). stake(amount, 4) / claimAll().
    address internal constant BLUAI_STAKE_BSC = 0x94b9865Ef26166fEBB7775d12d6dF23B51465040;

    /// @dev ORDER OFT (Arb / Base / OP). Wrap this, never the Ethereum ERC-20.
    address internal constant ORDER_OFT = 0x4E200fE2f3eFb977d5fd9c430A41531FB04d97B8;
    /// @dev Circle native USDC on Arbitrum (ORDER harvest hop). Not ORDER.
    address internal constant USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /// @dev Ethereum ORDER ERC-20. Never wrap this. hORDER inner is the OFT.
    address internal constant ORDER_ETH = 0xABD4C63d2616A5201454168269031355f4764337;
    /// @dev Orderly staking proxy. Identical on Eth/Arb/OP/Polygon/Base/Avax.
    address internal constant ORDERLY_PROXY = 0xC8A8Ce0Ab010E499ca57477AC031358febCbbF17;

    /// @dev SKY (Ethereum). Not MKR. Lockstake V2 is SKY-only.

    /// @dev SKY (Ethereum). Not MKR. Lockstake V2 is SKY-only.
    address internal constant SKY_ETH = 0x56072C95FAA701256059aa122697B133aDEd9279;
    address internal constant LOCKSTAKE_ENGINE = 0xCe01C90dE7FD1bcFa39e237FE6D8D9F569e8A6a3;
    address internal constant SKY_USDS_REWARDS = 0x38E4254bD82ED5Ee97CD1C4278FAae748d998865;

    uint256 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant BSC_CHAIN_ID = 56;
}
