// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Orderly proxy shape: stakeOrder(amount) payable, sendUserRequest(amount, type).
contract MockOrderlyProxy {
    IERC20 public immutable oft;
    mapping(address => uint256) public staked;
    uint256 public lastAmount;
    uint8 public lastType;
    address public lastCaller;

    constructor(IERC20 t) {
        oft = t;
    }

    function stakeOrder(uint256 amount) external payable {
        oft.transferFrom(msg.sender, address(this), amount);
        staked[msg.sender] += amount;
        lastCaller = msg.sender;
        lastAmount = amount;
    }

    function sendUserRequest(uint256 amount, uint8 payloadType) external payable {
        lastCaller = msg.sender;
        lastAmount = amount;
        lastType = payloadType;
    }
}
