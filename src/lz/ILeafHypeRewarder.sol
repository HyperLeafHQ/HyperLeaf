// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Minimal OFT surface so Rewarder.register can bind id ↔ token ↔ this.
interface ILeafOFTRewardBind {
    function hypeRewarder() external view returns (address);
    function listingId() external view returns (bytes32);
}

interface ILeafHypeRewarder {
    function settle(bytes32 id, address user) external;
    function updateDebt(bytes32 id, address user) external;
    function notify(bytes32 id, uint256 amount) external;
}
