// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Sky Lockstake Engine V2 (Ethereum): 0xCe01C90dE7FD1bcFa39e237FE6D8D9F569e8A6a3
/// @dev SKY-only. `free` burns an exit fee. V1 HyperLeaf never calls `draw` / `wipe`.
interface ISkyLockstake {
    function open(uint256 index) external returns (address urn);
    function lock(address owner, uint256 index, uint256 wad, uint16 ref) external;
    function free(address owner, uint256 index, address to, uint256 wad) external returns (uint256 freed);
    function selectFarm(address owner, uint256 index, address farm, uint16 ref) external;
    function selectVoteDelegate(address owner, uint256 index, address voteDelegate) external;
    function getReward(address owner, uint256 index, address farm, address to) external returns (uint256 amt);
}
