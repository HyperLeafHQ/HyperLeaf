// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/// @notice Testnet gSOON stand-in. LeafYieldFee reads convertToAssets(1e18).
contract MockConvertERC20 is MockERC20 {
    uint256 public assetsPerShare = 1e18;

    constructor(string memory name_, string memory symbol_) MockERC20(name_, symbol_) {}

    function setRate(uint256 r) external {
        assetsPerShare = r;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return shares * assetsPerShare / 1e18;
    }
}
