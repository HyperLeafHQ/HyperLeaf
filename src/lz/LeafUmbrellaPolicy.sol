// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hstkwaUSDC pins. Wrap stkwaEthUSDC.v1 only.
///         RewardsController is the poke target, never the StakeToken.
///         Never cooldown / redeem / v2 migrate / aUSDC / USDC / stkAAVE.
library LeafUmbrellaPolicy {
    address internal constant STKWA_USDC = 0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6;
    address internal constant REWARDS_CONTROLLER = 0x4655Ce3D625a63d30bA704087E52B4C31E38188B;
    address internal constant WA_ETH_USDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;
    bytes4 internal constant CLAIM_ALL_REWARDS = 0xbb492bf5;
    uint16 internal constant MAX_RATE_JUMP_BPS = 300;
    /// @dev 6-dec inner → 18-dec hstkwaUSDC.
    uint256 internal constant SHARE_SCALE = 1e12;
    uint8 internal constant INNER_DECIMALS = 6;

    error NotStkwaUsdc();
    error BadUmbrellaController();

    function requireStkwaUsdc(address inner) internal pure {
        if (inner != STKWA_USDC) revert NotStkwaUsdc();
    }

    function requireController(address controller, address inner) internal pure {
        if (controller != REWARDS_CONTROLLER) revert BadUmbrellaController();
        if (controller == address(0) || controller == inner) revert BadUmbrellaController();
    }

    /// @dev Dest share units per inner atom. 1e12 for hstkwausdc; 1 otherwise.
    function shareScaleOf(string memory id) internal pure returns (uint256) {
        bytes32 k = keccak256(bytes(id));
        if (k == keccak256("hstkwausdc") || k == keccak256("hstkwaUSDC")) return SHARE_SCALE;
        return 1;
    }
}
