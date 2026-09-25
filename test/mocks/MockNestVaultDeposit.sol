// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal vault used to unit-test Gate V2 residual routing.
contract MockNestVaultDeposit {
    IERC20 public immutable nestToken;
    IERC20 public immutable hNest;
    IERC20 public immutable hypeToken;
    mapping(address => uint256) public pendingResidualHype;

    constructor(IERC20 nestToken_, IERC20 hNest_, IERC20 hypeToken_) {
        nestToken = nestToken_;
        hNest = hNest_;
        hypeToken = hypeToken_;
    }

    function deposit(uint256 nestAmount) external {
        nestToken.transferFrom(msg.sender, address(this), nestAmount);
        require(hNest.transfer(msg.sender, nestAmount), "hNest");
    }

    function creditResidual(address user, uint256 amount) external {
        pendingResidualHype[user] += amount;
    }

    function claimResidualHype() external {
        uint256 amt = pendingResidualHype[msg.sender];
        pendingResidualHype[msg.sender] = 0;
        if (amt > 0) require(hypeToken.transfer(msg.sender, amt), "hype");
    }
}
