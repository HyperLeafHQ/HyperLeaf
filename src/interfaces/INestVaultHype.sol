// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title INestVaultHype
 * @notice Hooks called by HNest on peer-to-peer transfers to settle MasterChef residual-HYPE debt.
 * @dev "Hype" here means residual ERC20 swept into the vault — not Nest liquid HYPE rewards.
 */
interface INestVaultHype {
    /// @notice Settle (pay out) pending residual HYPE for `user` against current balance / acc.
    function settleResidualHype(address user) external;

    /// @notice Sync reward debt to current hNEST balance after a transfer.
    function updateDebt(address user) external;
}
