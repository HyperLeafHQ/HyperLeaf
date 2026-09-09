// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Adapter surface for a stable-asset Leaf. The adapter owns the venue-specific
///         evidence/exit logic; HyperLeaf only consumes normalized risk facts.
interface IStableAssetAdapter {
    struct PegState {
        uint256 marketPrice;          // 1e18 quote of the stable asset
        uint256 referencePrice;       // normally 1e18 USD, or the approved fiat reference
        uint256 primaryRedeemPrice;   // 1e18 net exit value, after venue fees/slippage
        uint256 updatedAt;
        uint16 deviationBps;          // absolute market/reference deviation
    }

    struct ExitState {
        uint256 totalClaim;            // normalized face-value claim
        uint256 immediatelyRedeemable; // primary venue liquidity available now
        uint256 bufferedLiquidity;     // protocol-controlled approved buffer
        uint256 queuedAmount;           // claim already waiting in an external queue
        uint256 updatedAt;
    }

    function pegState(bytes32 listingId) external view returns (PegState memory);
    function exitState(bytes32 listingId) external view returns (ExitState memory);

    function previewPrimaryExit(bytes32 listingId, uint256 shares)
        external
        view
        returns (uint256 assets, uint256 slippageBps);

    function primaryExit(bytes32 listingId, uint256 shares, uint256 minAssets, address receiver)
        external
        returns (uint256 assets);
}
