// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/// @notice Umbrella RewardsController stand-in. claimAllRewards([stk], lockbox).
contract MockRewardsController {
    MockERC20 public immutable reward;
    mapping(address => uint256) public pending;

    constructor(MockERC20 reward_) {
        reward = reward_;
    }

    function seed(address user, uint256 amount) external {
        pending[user] += amount;
        reward.mint(address(this), amount);
    }

    function claimAllRewards(address[] calldata, address to)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        uint256 a = pending[msg.sender];
        pending[msg.sender] = 0;
        if (a > 0) reward.transfer(to, a);
        rewardsList = new address[](1);
        rewardsList[0] = address(reward);
        claimedAmounts = new uint256[](1);
        claimedAmounts[0] = a;
    }
}
