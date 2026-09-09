// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockERC20} from "./MockERC20.sol";

/// @notice Testnet stand-in for xSQUID: claimRewards(address,uint256) 0x9a99b4f0.
contract MockClaimInner is ERC20 {
    MockERC20 public immutable reward;

    constructor(string memory name_, string memory symbol_, address reward_) ERC20(name_, symbol_) {
        reward = MockERC20(reward_);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function claimRewards(address to, uint256) external {
        reward.mint(to, 1 ether);
    }
}
