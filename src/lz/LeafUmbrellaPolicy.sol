// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hstkwaUSDC pins. Ethereum Umbrella StakeToken v1 only.
///         Controller is RewardsController, never the StakeToken.
library LeafUmbrellaPolicy {
    address internal constant STKWA_ETH_USDC_V1 = 0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6;
    address internal constant REWARDS_CONTROLLER = 0x4655Ce3D625a63d30bA704087E52B4C31E38188B;
    bytes4 internal constant CLAIM_ALL_REWARDS = 0xbb492bf5;

    error NotStkwaUsdc();
    error NotUmbrellaController();

    function requireStkwaUsdc(address inner) internal pure {
        if (inner != STKWA_ETH_USDC_V1) revert NotStkwaUsdc();
    }

    function requireController(address controller) internal pure {
        if (controller != REWARDS_CONTROLLER) revert NotUmbrellaController();
    }
}
