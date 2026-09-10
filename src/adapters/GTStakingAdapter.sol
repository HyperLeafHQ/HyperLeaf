// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGTStaking} from "../interfaces/IGTStaking.sol";

/// @title GTStakingAdapter
/// @notice Conservative accounting boundary for a future GateChain GT staking integration.
/// @dev The protocol-specific ABI MUST be verified before deployment. This adapter intentionally
///      does not deposit, withdraw, bridge, mint hGT, or infer NAV from GT spot price.
contract GTStakingAdapter {
    error ZeroAddress();

    IGTStaking public immutable staking;
    address public immutable gt;

    constructor(address _staking, address _gt) {
        if (_staking == address(0) || _gt == address(0)) revert ZeroAddress();
        staking = IGTStaking(_staking);
        gt = _gt;
    }

    /// @notice Source-side productive principal plus currently claimable staking rewards.
    /// @dev This is only a placeholder accounting boundary until the live GateChain ABI is verified.
    function verifiedNav(address account) external view returns (uint256) {
        return staking.stakedBalance(account) + staking.pendingRewards(account);
    }

    function stakedPrincipal(address account) external view returns (uint256) {
        return staking.stakedBalance(account);
    }

    function pendingRewards(address account) external view returns (uint256) {
        return staking.pendingRewards(account);
    }

    function healthy(address account) external view returns (bool) {
        return staking.stakedBalance(account) > 0;
    }
}
