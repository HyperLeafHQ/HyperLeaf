// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/// @notice Testnet cbETH stand-in. `exchangeRate()` is what LeafYieldFee reads.
contract MockRateERC20 is MockERC20 {
    uint256 public exchangeRate = 1e18;

    constructor(string memory name_, string memory symbol_) MockERC20(name_, symbol_) {}

    function setRate(uint256 r) external {
        exchangeRate = r;
    }
}
