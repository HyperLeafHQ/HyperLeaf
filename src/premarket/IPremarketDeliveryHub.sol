// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice HyperEVM-side hub. Inbound credit calls Factory.onDeliveryCredit.
///         Outbound notifyRelease unlocks official tokens on the origin chain.
interface IPremarketDeliveryHub {
    function notifyRelease(bytes32 seriesId, address to, uint256 amount) external payable;
}
