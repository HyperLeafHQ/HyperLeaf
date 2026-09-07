// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Sky Lockstake Engine V2: 0xCe01C90dE7FD1bcFa39e237FE6D8D9F569e8A6a3
/// @dev This deployment: fee() == 0 (immutable). lsSKY 0xf9A9cfD3… is minted to the urn, not to us.
///      V1 never draw/wipe. One farm per urn. USDS farm 0x38E4254b… pays USDS; SPK farm also ACTIVE.
interface ISkyLockstake {
    function fee() external view returns (uint256);
    function sky() external view returns (address);
    function lssky() external view returns (address);
    function usds() external view returns (address);
    function farms(address) external view returns (uint8);
    function open(uint256 index) external returns (address urn);
    function lock(address owner, uint256 index, uint256 wad, uint16 ref) external;
    function free(address owner, uint256 index, address to, uint256 wad) external returns (uint256 freed);
    function selectFarm(address owner, uint256 index, address farm, uint16 ref) external;
    function selectVoteDelegate(address owner, uint256 index, address voteDelegate) external;
    function getReward(address owner, uint256 index, address farm, address to) external returns (uint256 amt);
}
