// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Collateral and payment asset adapter. v1 parks a plain ERC-20.
interface ILeafStableAsset {
    function underlying() external view returns (address);
    function deposit(uint256 amount) external;
    function redeem(uint256 amount) external;
    function harvest() external returns (uint256 realized);
    function totalAssets() external view returns (uint256);
}
