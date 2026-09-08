// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockLbtcRouter {
    mapping(address => uint256) public rateOf;

    function setRate(address token, uint256 r) external {
        rateOf[token] = r;
    }

    function getRate(address token) external view returns (uint256) {
        uint256 r = rateOf[token];
        return r == 0 ? 1e18 : r;
    }
}
