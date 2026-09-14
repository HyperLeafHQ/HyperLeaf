// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockMerkleAirdrop {
    IERC20 public immutable hype;
    mapping(address => uint256) public cumulative;
    mapping(address => uint256) public claimed;

    constructor(address hype_) {
        hype = IERC20(hype_);
    }

    function setEntitlement(address who, uint256 amount) external {
        cumulative[who] = amount;
    }

    function claim(bytes32[] calldata, address addr_, uint256 amount_) external {
        require(amount_ <= cumulative[addr_], "amt");
        require(amount_ >= claimed[addr_], "claimed");
        uint256 delta = amount_ - claimed[addr_];
        claimed[addr_] = amount_;
        if (delta > 0) require(hype.transfer(addr_, delta), "xfer");
    }
}
