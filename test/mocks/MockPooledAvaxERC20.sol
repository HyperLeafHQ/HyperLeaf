// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/// @notice Testnet sAVAX stand-in. LeafYieldFee reads getPooledAvaxByShares(1e18).
contract MockPooledAvaxERC20 is MockERC20 {
    uint256 public pooledPerShare = 1e18;

    constructor(string memory name_, string memory symbol_) MockERC20(name_, symbol_) {}

    function setRate(uint256 r) external {
        pooledPerShare = r;
    }

    function setPooled(uint256 r) external {
        pooledPerShare = r;
    }

    function getPooledAvaxByShares(uint256 shares) external view returns (uint256) {
        return shares * pooledPerShare / 1e18;
    }
}
