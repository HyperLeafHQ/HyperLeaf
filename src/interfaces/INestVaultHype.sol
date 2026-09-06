// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title INestVaultHype
 * @notice Hooks called by HNest on peer-to-peer transfers to settle MasterChef HYPE debt.
 */
interface INestVaultHype {
    /// @notice Settle (pay out) pending HYPE for `user` against current balance / acc.
    function settleHype(address user) external;

    /// @notice Sync reward debt to current hNEST balance after a transfer.
    function updateDebt(address user) external;
}
