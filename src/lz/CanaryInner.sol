// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @dev Worthless mainnet inner for the LZ canary. Owner mints. Not a listing.
contract CanaryInner is ERC20, Ownable {
    constructor(address owner_) ERC20("HyperLeaf Canary Inner", "LEAFTEST") Ownable(owner_) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
