// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice JitoSOL is SPL 9 decimals. Dest hJitoSOL is 18. Same 1% retain math as
///         LeafYieldFee._bookRetainFee. Solana program must match these numbers.
///         Never CPI the stake pool (no depositSol / withdrawSol / depositStake).
library LeafJitoRate {
    uint16 internal constant YIELD_FEE_BPS = 100;
    uint16 internal constant BPS = 10_000;
    uint256 internal constant RATE_SCALE = 1e18;
    uint256 internal constant SHARE_SCALE = 1e9; // 9 → 18

    error BadRate();
    error Zero();

    /// @dev stake pool: total_lamports * 1e18 / pool_token_supply.
    ///      Both sides are native 9-decimal quantities. pool_mint MUST be JitoSOL.
    function rate(uint64 totalLamports, uint64 poolTokenSupply) internal pure returns (uint256) {
        if (poolTokenSupply == 0) revert BadRate();
        return (uint256(totalLamports) * RATE_SCALE) / uint256(poolTokenSupply);
    }

    function sharesFromAtoms(uint256 atoms) internal pure returns (uint256) {
        if (atoms == 0) revert Zero();
        return atoms * SHARE_SCALE;
    }

    /// @dev Floor. Dust atoms stay in the PDA (protocol-favorable).
    function atomsFromShares(uint256 shares, uint256 lastAccountedAtoms, uint256 totalShares)
        internal
        pure
        returns (uint256)
    {
        if (shares == 0 || totalShares == 0 || lastAccountedAtoms == 0) return 0;
        return (shares * lastAccountedAtoms) / totalShares;
    }

    function sharesForAtoms(uint256 atoms, uint256 lastAccountedAtoms, uint256 totalShares)
        internal
        pure
        returns (uint256)
    {
        if (atoms == 0) revert Zero();
        if (totalShares == 0 || lastAccountedAtoms == 0) return sharesFromAtoms(atoms);
        uint256 prev = lastAccountedAtoms;
        return (atoms * totalShares) / prev;
    }

    /// @dev On rate ↑: fee = 1% of (lastAccounted * dRate / rate), floor.
    ///      lastAccounted is reduced by the fee only. 99% stays as atoms.
    ///      On rate ↓: watermark drops, fee 0.
    function bookRetainFee(uint256 lastAccounted, uint256 lastRate, uint256 newRate)
        internal
        pure
        returns (uint256 fee, uint256 nextAccounted, uint256 nextRate)
    {
        if (newRate == 0) revert BadRate();
        if (lastRate == 0 || lastAccounted == 0) return (0, lastAccounted, newRate);
        if (newRate < lastRate) return (0, lastAccounted, newRate);
        if (newRate == lastRate) return (0, lastAccounted, lastRate);
        uint256 add = (lastAccounted * (newRate - lastRate)) / newRate;
        fee = (add * YIELD_FEE_BPS) / BPS;
        if (fee > lastAccounted) fee = lastAccounted;
        return (fee, lastAccounted - fee, newRate);
    }
}
